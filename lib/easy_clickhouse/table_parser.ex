defmodule EasyClickhouse.TableParser do
  @moduledoc false

  require Logger
  alias EasyClickhouse.Types

  @columns_sql ~s"""
  SELECT
    name AS column_name,
    type AS data_type,
    default_expression AS default_value
  FROM system.columns
  WHERE database = {database:String} AND table = {table_name:String}
  ORDER BY position
  """

  @doc """
  Returns the table structure as a list of columns with their types.
  """
  @spec get_table_structure(String.t(), String.t()) :: Types.table()
  def get_table_structure(database, table_name) do
    case EasyClickhouse.ChServer.conn()
         |> Ch.query(@columns_sql, %{
           "database" => database,
           "table_name" => table_name
         }) do
      {:ok, %Ch.Result{rows: rows = [_ | _]}} ->
        {:ok,
         rows
         |> Enum.map(fn [name, type, default] ->
           %{
             name: name,
             type: type,
             default: default
           }
         end)}

      e ->
        Logger.error(inspect(e))
        :error
    end
  end

  @spec opts(Types.rows(), list(String.t())) :: Types.opts()
  def opts(rows, except \\ []) do
    rows
    |> Enum.reduce(
      [names: [], types: []],
      fn %{name: name, type: type}, [names: names, types: types] = acc ->
        cond do
          name in except -> acc
          true -> [names: [name | names], types: [type | types]]
        end
      end
    )
    |> Enum.map(fn {name, values} -> {name, Enum.reverse(values)} end)
  end

  @spec get_table_opts(String.t(), String.t(), [String.t()]) :: Types.opts() | :error
  def get_table_opts(database, table_name, except \\ []) do
    case get_table_structure(database, table_name) do
      {:ok, table} -> opts(table, except)
      _ -> :error
    end
  end
end
