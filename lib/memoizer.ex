defmodule Memoizer do
  @moduledoc """
  Memoizer turns an ordinary Elixir module into a transparent service that
  memoizes (aka caches) your function calls.  The first function call may
  take a very long time:

    iex> :tc.timer(Ultimate, :answer, [:life, :universe, :everything])
    {7.5 million years in microseconds, 42}

  but further calls happen almost instantaneously when the answer is already available:

    iex> :tc.timer(Ultimate, :answer, [:life, :universe, :everything])
    {0, 42}

  Here's a simple example how to us it.  Let's make the module below a memoized
  one:

      defmodule Memo do
        def fact(0), do: 1
        def fact(n), do: n * fact(n - 1)
      end

  The modification is simple:

      defmemo Memo do
        use Memoizer

        def     fact(0), do: 1
        defmemo fact(n), do: n * fact(n - 1)
      end

  It is also important that `Memo` has to be started before you start
  calculating values.  The simplest way is to call `Memo.start_link` if you
  are just playing around, but you should consider putting it under supervision.

  When the service is running, you can make calls to the functions just as they
  were defined in the first place: `Memo.fact(100)`.  This caches the return
  values of `fact/1` for params between 2 and 100.  Next time you call the
  function within this range, the stored value is returned.

  With `defmemo` you can also use `when` gueards, and it's legal to mix simple
  `def`s with `defmemo` definitions.  This enables you to have a fine grained
  controll over what makes it into the cache and what gets calculated over and
  over again with every function call.  For instance, it does not make much
  sense to memoize `fact(0)` in the example above, so we can keep this case in
  a normal function clause. Here's an example of calculating the Fibonacci
  sequence with only memoizing `fib(n)` when n or n-1 can be divided by 7.
  This reduces the memory footprint to 2/7 of the version memoizing every value:

      def     fib(0),                     do: 0
      def     fib(1),                     do: 1
      def     fib(n) when rem(n, 7) == 2, do:  1 * fib(n - 1) +  1 * fib(n - 2)
      def     fib(n) when rem(n, 7) == 3, do:  2 * fib(n - 2) +  1 * fib(n - 3)
      def     fib(n) when rem(n, 7) == 4, do:  3 * fib(n - 3) +  2 * fib(n - 4)
      def     fib(n) when rem(n, 7) == 5, do:  5 * fib(n - 4) +  3 * fib(n - 5)
      def     fib(n) when rem(n, 7) == 6, do:  8 * fib(n - 5) +  5 * fib(n - 6)
      defmemo fib(n) when rem(n, 7) == 0, do: 13 * fib(n - 6) +  8 * fib(n - 7)
      defmemo fib(n) when rem(n, 7) == 1, do: 21 * fib(n - 7) + 13 * fib(n - 8)

  You may want to normalize the arguments of a function call before making the
  expensive function call, or post-process the returned value before returning
  it to the caller.  In this case you can use `defmemop` to define your
  calculation, and wrap the call in a public function that makes the necessary
  transformations and normalizations. `defmemop` can be mixed with `defp`
  caluses just like `defmemo` and `def`.

  While memoizing pure functions does not change the semantics of your program,
  nothings stops you applying the technique to non-pure functions.  This may
  make sense in certain situations.  In this case functions like
  `Memoizer.forget`, `Memoizer.memoized?` and `Memoizer.learn` can come in
  handy. It is a deliberate decision that these functions are kept in the
  `Memoizer` module and are not injected into the modules that `use Memoizer`.

  If you are after more performance, `Memoizer.compile` can give you some more
  speed by compiling the currently cached function clauses into a separate module.
  """

  defmacro __using__(_) do
    memoizer_module = __MODULE__
    quote do
      import unquote(memoizer_module)

      use GenServer

      def start_link do
        GenServer.start_link __MODULE__, [], name: __MODULE__
      end

      def init(_) do
        IO.inspect self()
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

      def handle_call({:learn, function_name, params, return_value}, _, state) do
        __MODULE__ |> :ets.insert({{function_name, params}, return_value})
        {:reply, :ok, state}
      end

      def handle_call({:forget, function_name, params}, _, state) do
        __MODULE__ |> :ets.delete({function_name, params})
        {:reply, :ok, state}
      end

      def handle_call({:forget, function_name}, _, state) do
        __MODULE__ |> :ets.match_delete({{:fib, :'$1'}, :'$2'})
        {:reply, :ok, state}
      end

      def handle_call({:forget}, _, state) do
        __MODULE__ |> :ets.delete_all_objects
        {:reply, :ok, state}
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

  @doc """
  Checks if the `function` in the `module` with the `params` is memoized.

  `module` has to be a module using the Memoizer.
  `module` and `function` are atoms, `params` is the list of function arguments.
  The call returns `true` or `false`.

  """

  def memoized?(module, function, params) do
    key = {function, params}
    module |> :ets.member(key)
  end

  @doc """
  Stores the `return_value` of the `function` in the module `module` associated with
  the arguments `params`.

  Blocks the caller until the cache update takes effect.

  If the value was already cached, this call replaces the old value with the new one.

  Returns the module name in order to make chaining of Memoizer calls simple.

  ## Example

      MyModule
      |> Memoizer.learn(:funct, [1], "one")
      |> Memoizer.learn(:funct, [2], "two")
      |> Memoizer.forget(:funct, [500])
      |> Memoizer.memoized?(:funct, [500]) # => false
  """

  def learn(module, function, params, return_value) do
    GenServer.call(module, {:learn, function, params, return_value})
    module
  end

  @doc """
  Asks Memoizer to forget the return value associated with the `function` in the
  `module` when called with the `params`.

  Blocks the caller until the cache modification takes effect.

  Returns the `module` in order to make it simple to call `Memoizer` API functions
  in a chained manner.
  """

  def forget(module, function, params) do
    GenServer.call(module, {:forget, function, params})
    module
  end

  @doc """
  `forget(module, function)` forces Memoizer to delete all cached cases of the
  `function` in the `module`.
  """
  def forget(module, function) do
    GenServer.call(module, {:forget, function})
    module
  end

  @doc """
  `forget(module)` deletes all cached data of all functions under the given `module`.
  """
  def forget(module) do
    GenServer.call(module, {:forget})
    module
  end

  @doc """
  Compiles the given Memoizer `module` into another module where the memoized
  function calls are defined as separate function caluses.

      defmodule M do
        use Memoizer

        defmemo f(n), do: n + 100
      end

      M.start_link

      M.f 100  # =>  200
      M.f 1000 # => 1100

      Memoizer.compile M, into: CompileTest

  This creates a module called `CompileTest` as if it were defined as follows:

      defmodule CompileTest do
        def f(100),  do: 200
        def f(1000), do: 1100
      end

  Compilation is a very slow process, especially when there are a huge number
  of memoized cases.  However, the compiled version can be approximately 30%
  faster than the simple, memoized function calls.  You may take advantage of
  the Erlang runtime allowing you to have two loaded versions of modules loaded
  at the same time.
  """

  def compile(module, opts \\ []) do
    new_module_name = opts[:into] || Module.concat(module, CompiledMemo)

    Module.create(new_module_name,
      :ets.foldr(fn {{function_name, params}, return_value}, acc ->
        [
          quote do
            def unquote(function_name)(unquote_splicing(params)) do
              unquote(return_value)
            end
          end

        | acc ]
      end, [], module),
      [file: opts[:file] || ""]
    )
  end
end

