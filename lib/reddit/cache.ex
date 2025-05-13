defmodule Reddit.Cache do
  @moduledoc """
  ETS-based cache for the Reddit application.
  Stores and retrieves data with TTL (Time-To-Live) support.
  """
  use GenServer

  @table_name :reddit_cache
  # Default TTL is 1 minute
  @default_ttl :timer.minutes(1)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets a value from the cache by key.
  Returns nil if the key doesn't exist or value has expired.
  """
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expires_at}] ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
          value
        else
          nil
        end

      [] ->
        nil
    end
  end

  @doc """
  Puts a value in the cache with a key and optional TTL.
  """
  def put(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    :ets.insert(@table_name, {key, value, expires_at})
    value
  end

  @doc """
  Deletes a value from the cache by key.
  """
  def delete(key) do
    :ets.delete(@table_name, key)
    :ok
  end

  # Homepage links specific functions

  @doc """
  Gets homepage links from the cache.
  """
  def get_homepage_links do
    get("homepage_links")
  end

  @doc """
  Puts homepage links in the cache.
  """
  def put_homepage_links(links) do
    put("homepage_links", links)
  end

  @doc """
  Deletes homepage links from the cache.
  """
  def delete_homepage_links do
    delete("homepage_links")
  end

  # Server Callbacks

  @impl true
  def init(_) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    _now = DateTime.utc_now()
    # Matching for expired entries and removing them
    # Match any value where the expires_at date is earlier than now
    :ets.match_delete(@table_name, {:_, :_, :"$1"})
    schedule_cleanup()
    {:noreply, state}
  end

  # Schedule cache cleanup every minute
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(1))
  end
end
