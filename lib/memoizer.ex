defmodule Memoizer do
  defmacro __using__(_) do
    memoizer_module = __MODULE__
    quote do
      import unquote(memoizer_module)

      use GenServer

      def start_link(_) do
        GenServer.start_link __MODULE__, [], name: __MODULE__
      end

      def init(_) do
        IO.inspect self
        __MODULE__ |> :ets.new([:ordered_set, :protected, :named_table, {:read_concurrency, true}])
        {:ok, nil}
      end

      def handle_cast({:put, key, value}, state) do
        __MODULE__ |> :ets.insert({key, value})
        {:noreply, state}
      end

      def handle_cast(_, state) do
        {:noreply, state}
      end

      def handle_call(_, _, state) do
        {:reply, :ok, state}
      end

      def handle_info(msg, state) do
        {:noreply, state}
      end
    end
  end

  defmacro defmemo(head = {name, _, params}, do: body) do
    quote do
      def unquote(head) do
        key = {unquote(name), unquote(params)}

        __MODULE__
        |> :ets.lookup(key)
        |> case do

          [{_, value}] ->
            value

          _ ->
            value = unquote(body)
            __MODULE__ |> GenServer.cast({:put, key, value})
            value
        end
      end
    end
  end
end

