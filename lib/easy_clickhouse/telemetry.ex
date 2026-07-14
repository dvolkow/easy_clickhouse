defmodule EasyClickhouse.Telemetry do
  require Logger
  use GenServer
  @ets_table :easy_clickhouse_telemetry

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def metrics do
    :ets.tab2list(@ets_table)
  end

  def fetch(metric) do
    case :ets.lookup(@ets_table, metric) do
      [{^metric, value}] -> value
      _ -> nil
    end
  end

  defp attach(name, event),
    do:
      :telemetry.attach(
        name,
        event,
        &EasyClickhouse.Telemetry.handle_event/4,
        nil
      )

  @impl true
  def init(_arg) do
    :ets.new(
      @ets_table,
      [
        :named_table,
        :public,
        :set,
        {:read_concurrency, true}
      ]
    )

    attach("insert", [:easy_clickhouse, :insert])
    attach("init_batcher", [:easy_clickhouse, :init_batcher])
    attach("term_batcher", [:easy_clickhouse, :terminate_batcher])
    {:ok, %{}}
  end

  def handle_event(
        [:easy_clickhouse, :insert],
        %{ts: ts, rows: rows, status: status} = _measurements,
        %{db: db, table: table} = _metadata,
        _config
      ) do
    safe_incr(:total_inserts)
    safe_incr({:total_inserts, db, table})
    set({:last_insert, db, table}, {ts, rows, status})

    case status do
      :ok ->
        safe_incr(:total_insert_rows, rows)
        safe_incr({:insert_rows, db, table}, rows)

      _ ->
        safe_incr(:total_insert_errs)
        safe_incr({:insert_errs, db, table})
    end
  end

  def handle_event(
        [:easy_clickhouse, :init_batcher],
        %{ts: ts},
        %{db: db, table: table},
        _config
      ) do
    safe_incr({:batcher_inits, db, table})
    set({:batcher_init, db, table}, ts)
  end

  def handle_event(
        [:easy_clickhouse, :terminate_batcher],
        %{ts: ts, reason: reason},
        %{db: db, table: table},
        _config
      ) do
    safe_incr({:batcher_terminates, db, table})
    set({:batcher_terminate, db, table}, {ts, reason})
  end

  defp safe_incr(metric, count \\ 1) do
    unless :ets.insert_new(@ets_table, {metric, count}) do
      :ets.update_counter(@ets_table, metric, {2, count})
    end
  end

  defp set(metric, value) do
    :ets.insert(@ets_table, {metric, value})
  end
end
