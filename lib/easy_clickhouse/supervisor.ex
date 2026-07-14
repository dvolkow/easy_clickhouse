defmodule EasyClickhouse.Supervisor do
  @moduledoc false
  use Supervisor
  @ets_table :easy_clickhouse_supervisor

  alias EasyClickhouse.Types

  @spec define_supervisor(atom(), atom(), integer(), list(String.t())) :: Supervisor.child_spec()
  defp define_supervisor(database, table_name, rate, except_list \\ []) do
    :ets.insert(@ets_table, {{database, table_name}, {rate, except_list}})

    Supervisor.child_spec(
      {EasyClickhouse.Batcher,
       name: {:via, Registry, {EasyClickhouse.Registry, registry_name(database, table_name)}},
       config: %{
         rate: rate,
         database: Atom.to_string(database),
         table: Atom.to_string(table_name),
         except: except_list,
         queue: [],
         qlength: 0
       }},
      id: table_name
    )
  end

  @spec batchers() :: [{{atom(), atom()}, pid() | nil}]
  def batchers() do
    :ets.tab2list(@ets_table)
    |> Enum.map(fn {db, table} ->
      case Registry.lookup(EasyClickhouse.Registry, registry_name(db, table)) do
        [{pid, _}] ->
          {{db, table}, pid}

        [] ->
          {{db, table}, nil}
      end
    end)
  end

  def start_link(init_state) do
    Supervisor.start_link(__MODULE__, init_state, name: __MODULE__)
  end

  @spec registry_name(atom(), atom()) :: {atom(), atom()}
  def registry_name(database, table_name), do: {database, table_name}

  @spec get_children([Types.supervisor_table()]) :: [Supervisor.child_spec()]
  defp get_children(tables) do
    [
      Registry.child_spec(keys: :unique, name: EasyClickhouse.Registry)
      | Enum.map(tables, fn
          {database, table, rate} ->
            define_supervisor(database, table, rate)

          {database, table, rate, except} ->
            define_supervisor(database, table, rate, except)
        end)
    ]
  end

  @impl true
  def init(opts) do
    :ets.new(@ets_table, [:named_table, :set, :public, read_concurrency: true])

    case Keyword.get(opts, :tables) do
      nil ->
        :error

      tables ->
        ch_timeout_sec = Keyword.get(opts, :ch_timeout_sec)

        children =
          [EasyClickhouse.Telemetry, {EasyClickhouse.ChServer, timeout_sec: ch_timeout_sec}] ++
            get_children(tables)

        children
        |> Supervisor.init(strategy: :one_for_one)
    end
  end
end
