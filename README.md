# EasyClickhouse

**Accumulation and periodic sending of data to Clickhouse from Elixir apps.**

## Installation

```elixir
def deps do
  [
    {:easy_clickhouse,
      git: "https://github.com/dvolkow/easy_clickhouse.git", branch: "master"}
  ]
end

```

## Usage

It often happens that you have a table (or several tables) into which you write data
from the application.

Let's say you have a database `:your_database` and a table `:your_table`, and you know
the time interval `rate` (must be in milliseconds!) at which you want to send data.

Now you can do this declaratively if you have Elixir. Just add it to the supervisor tree:

```elixir
  tables = [
      {:your_database, :your_table, rate}
    ]

  children = [
      {EasyClickhouse.Supervisor, tables: tables}
  ]
```
