defmodule EasyClickhouse.Types do
  @type row() :: [any()]

  @type supervisor_table() :: {atom(), atom(), integer()}

  @type table_row() :: %{
          required(:name) => String.t(),
          required(:type) => String.t(),
          required(:default) => String.t()
        }
  @type table() :: {:ok, [table_row()]} | :error

  @type rows() :: [names: [String.t()], types: [String.t()]]
  @type opts() :: [{[String.t()], [String.t()]}]
end
