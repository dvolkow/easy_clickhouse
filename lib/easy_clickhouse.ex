defmodule EasyClickhouse do
  @moduledoc """
  Add to your supervisor tree:

  update_rate_ms = 10_000 # every 10 seconds push from queue

  tables = [
      {:your_database, :your_table, update_rate_ms}
    ]

  children = [
      {EasyClickhouse.Supervisor, tables: tables}
  ]
  """
  alias EasyClickhouse.Types

  @doc """
  Push row to batcher's queue.
  """
  @spec enqueue(Types.row(), atom(), atom()) :: :ok
  def enqueue(row, database, table) when is_list(row) do
    GenServer.cast(
      {:via, Registry,
       {EasyClickhouse.Registry, EasyClickhouse.Supervisor.registry_name(database, table)}},
      {:enqueue, row}
    )
  end

  @doc """
  Push rows list to batcher's queue.
  """
  @spec enqueue_batch([Types.row()], atom(), atom()) :: :ok
  def enqueue_batch(rows, database, table) when is_list(rows) do
    GenServer.cast(
      {:via, Registry,
       {EasyClickhouse.Registry, EasyClickhouse.Supervisor.registry_name(database, table)}},
      {:enqueue_batch, rows}
    )
  end

  @doc """
  Get table opts.
  """
  @spec table_opts(atom(), atom()) :: Types.opts()
  def table_opts(database, table) do
    GenServer.call(
      {:via, Registry,
       {EasyClickhouse.Registry, EasyClickhouse.Supervisor.registry_name(database, table)}},
      :opts
    )
  end
end
