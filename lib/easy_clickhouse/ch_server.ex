defmodule EasyClickhouse.ChServer do
  @moduledoc false
  @default_timeout_sec 60

  use GenServer
  require Logger

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  def init(initial_state) do
    timeout_sec = Keyword.get(initial_state, :timeout_sec)

    settings = [
      scheme: "http",
      hostname: Application.fetch_env!(:easy_clickhouse, :ch_host),
      port: Application.fetch_env!(:easy_clickhouse, :ch_port),
      database: Application.fetch_env!(:easy_clickhouse, :ch_database),
      settings: [
        user: Application.fetch_env!(:easy_clickhouse, :ch_user),
        password: Application.fetch_env!(:easy_clickhouse, :ch_password)
      ],
      pool_size: Application.fetch_env!(:easy_clickhouse, :ch_pool_size),
      timeout: :timer.seconds(timeout_sec || @default_timeout_sec)
    ]

    case Ch.start_link(settings) do
      {:ok, conn_pid} ->
        Logger.debug("start with #{inspect(initial_state)}")
        {:ok, conn_pid}

      _ ->
        {:stop, :error}
    end
  end

  def conn() do
    GenServer.call(__MODULE__, :conn)
  end

  def handle_call(:conn, _from, conn_pid) do
    {:reply, conn_pid, conn_pid}
  end

  @spec sql(String.t()) :: list(any())
  def sql(sql_query) do
    case conn() |> Ch.query(sql_query) do
      {:ok, result} -> result.rows
      _ -> []
    end
  end
end
