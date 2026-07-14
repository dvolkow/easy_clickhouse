defmodule EasyClickhouse.Supervisor do
  @moduledoc false
  use Supervisor

  alias EasyClickhouse.Types

  @spec define_supervisor(atom(), atom(), integer(), list(String.t())) :: Supervisor.child_spec()
  defp define_supervisor(database, table_name, rate, except_list \\ []) do
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
