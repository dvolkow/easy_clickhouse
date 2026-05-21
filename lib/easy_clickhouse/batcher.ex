defmodule EasyClickhouse.Batcher do
  @moduledoc false
  use GenServer
  require Logger

  alias EasyClickhouse.Types

  def start_link(opts) do
    name = Keyword.get(opts, :name)
    config = Keyword.get(opts, :config)
    GenServer.start_link(__MODULE__, config, name: name)
  end

  def init(%{rate: rate, database: database, table: table, except: except} = init_state) do
    Logger.debug("#{__MODULE__}:#{table} starting...")

    case EasyClickhouse.TableParser.get_table_opts(database, table, except) do
      :error ->
        Logger.error("#{__MODULE__}:#{table} failed for get table opts")
        :error

      opts ->
        schedule_update(rate)
        {:ok, init_state |> Map.put(:opts, opts)}
    end
  end

  defp schedule_update(rate) do
    Process.send_after(self(), :update_state, rate)
  end

  def handle_info(:update_state, %{rate: rate} = state) do
    schedule_update(rate)

    new_state =
      case check_and_push(state) do
        :ok ->
          state |> Map.merge(%{queue: [], qlength: 0})

        _ ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_call(:opts, %{opts: opts} = state) do
    {:reply, opts, state}
  end

  def handle_cast({:enqueue, row}, %{queue: queue, qlength: qlength} = state)
      when is_list(row) do
    {:noreply, state |> Map.merge(%{qlength: qlength + 1, queue: [row | queue]})}
  end

  def handle_cast({:enqueue_batch, rows}, %{queue: queue, qlength: qlength} = state)
      when is_list(rows) do
    {:noreply, state |> Map.merge(%{qlength: qlength + Enum.count(rows), queue: rows ++ queue})}
  end

  @spec ch_insert([Types.row()], atom(), atom(), Types.opts()) :: :ok | :error
  def ch_insert(queue, database, table, opts) when is_list(queue) do
    sql = "INSERT INTO #{database}.#{table} FORMAT RowBinaryWithNamesAndTypes"
    ref_length = Enum.count(queue)

    case EasyClickhouse.ChServer.conn() |> Ch.query(sql, queue, opts) do
      {:ok, %Ch.Result{num_rows: num_rows}} when num_rows == ref_length ->
        Logger.debug("inserted #{num_rows} rows to #{database}.#{table}")
        :ok

      {:ok, %Ch.Result{num_rows: num_rows}} ->
        Logger.warning("inserted #{num_rows} instead of ref_length to #{database}.#{table}")
        :error

      e ->
        Logger.warning("#{inspect(e)}")

        GenServer.cast(
          {:via, Registry,
           {EasyClickhouse.Registry, EasyClickhouse.Supervisor.registry_name(database, table)}},
          {:enqueue_batch, queue}
        )
    end
  end

  defp check_and_push(state) do
    if state.qlength > 0 do
      Logger.debug("push to clickhouse #{state.database}.#{state.table} #{state.qlength} rows...")

      push(state)
    end
  end

  defp push(%{queue: queue, database: database, table: table, opts: opts}) do
    Task.start(fn -> ch_insert(queue, database, table, opts) end)

    :ok
  end
end
