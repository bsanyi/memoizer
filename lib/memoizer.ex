defmodule Memoizer do
  defmacro __using__(_) do
    memoizer_module = __MODULE__
    quote do
      import unquote(memoizer_module)

      use GenServer

      def start_link do
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

  defmacrop __defmemo__(head, name, params, body, priv) do
    quote do
      head   = unquote(head)
      name   = unquote(name)
      params = unquote(params)
      body   = unquote(body)

      fn_body =
        quote do
          key = {unquote(name), unquote(params)}

          case :ets.lookup(__MODULE__, key) do

            [{_, value}] ->
              value

            _ ->
              value = unquote(body)
              __MODULE__ |> GenServer.cast({:put, key, value})
              value
          end
        end

      if unquote(priv) do
        quote do
          defp unquote(head), do: unquote(fn_body)
        end
      else
        quote do
          def  unquote(head), do: unquote(fn_body)
        end
      end
    end
  end

  defmacro defmemo(head = {:when, _, [{name, _, params}|_]}, do: body) do
    __defmemo__(head, name, params, body, false)
  end

  defmacro defmemo(head = {name, _, params}, do: body) do
    __defmemo__(head, name, params, body, false)
  end

  defmacro defmemop(head = {:when, _, [{name, _, params}|_]}, do: body) do
    __defmemo__(head, name, params, body, true)
  end

  defmacro defmemop(head = {name, _, params}, do: body) do
    __defmemo__(head, name, params, body, true)
  end
end

