defmodule EasyClickhouse.RowParser do
  @moduledoc false
  require Logger

  @type t() :: integer() | float() | String.t() | :inet.ip4_address()

  @default_ip_address :inet.parse_ipv4_address(~c"0.0.0.0") |> elem(1)
  @defaults %{
    "String" => "",
    "UInt16" => 0,
    "UInt32" => 0,
    "IPv4" => "0.0.0.0",
    "LowCardinality(String)" => "",
    "Float32" => 0.0,
    "Float64" => 0.0
  }

  @spec to_int(any()) :: integer()
  def to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {v_int, _} when is_number(v_int) -> v_int
      _ -> 0
    end
  end

  def to_int(value) when is_number(value) do
    value
  end

  def to_int(e) do
    Logger.warning("to_int: unknown value: #{inspect(e)}")
    0
  end

  @spec to_float(any()) :: float()
  def to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {v_float, _} when is_float(v_float) -> v_float
      _ -> 0.0
    end
  end

  def to_float(value) when is_number(value) do
    to_float("#{value}")
  end

  def to_float(e) do
    Logger.warning("to_float: unknown value: #{inspect(e)}")
    0.0
  end

  @spec to_ipv4(any()) :: :inet.ip4_address()
  def to_ipv4(value) when is_binary(value) do
    case value
         |> String.to_charlist()
         |> :inet.parse_ipv4_address() do
      {:ok, res} ->
        res

      _ ->
        @default_ip_address
    end
  end

  @doc """
  Returns the table row of a list of parsed values by their types.
  """
  @spec parse(map(), String.t(), String.t()) :: t()
  def parse(data, field_name, field_type) do
    data
    |> Map.get(field_name, @defaults[field_type])
    |> conv(field_type)
  end

  defp conv(value, type) do
    case type do
      "String" -> to_string(value)
      "UInt16" -> to_int(value)
      "UInt32" -> to_int(value)
      "Float32" -> to_float(value)
      "Float64" -> to_float(value)
      "IPv4" -> to_ipv4(value)
      _ -> value
    end
  end
end
