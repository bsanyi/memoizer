# Memoizer

Memoizer is an application that enables memoization of functions (that is, it
stores the results of expensive function calls and returns the cached result
when the same input occur again).

This is an optimization technique known in Dynamic Programming.


## Installation

The package can be installed as:

  1. Add memoizer to your list of dependencies in `mix.exs`.

        def deps do
          [
            ...
            {:memoizer, "~> 0.0.1"},
            ...
          ]
        end

  2. Ensure memoizer is installed into your application.

        mix deps.get


## Usage

Simply define a module and `use Memoizer` in it.  Then you can define functions
with the `defmemo` macro, just like with `def`.  Feel free to mix `def` and
`defmemo` to indicate what to memoize and what not.

    defmodule MemoExample do
      use Memoizer

      def     fib(0), do: 0
      def     fib(1), do: 1
      defmemo fib(n), do: fib(n - 1) + fib(n - 2)
    end

You can use guards just like with normal functions.  It is even possible to
control which part to memoize.  Here's a fib() variant that only memoizes every
5th value:

    def     sparse_fib(0), do: 0

    def     sparse_fib(1), do: 1

    defmemo sparse_fib(n) when rem(n, 5) == 0,
                    do: sparse_fib(n - 1) + sparse_fib(n - 2)

    def     sparse_fib(n),
                    do: sparse_fib(n - 1) + sparse_fib(n - 2)

`use Memoizer` turns the `MemoExample` module into an OTP worker that needs to
be started before you can apply the functions in it.  `MemoExample.start_link`
is the simplest way to do that in `iex`, or you can use a supervisor to take
care of it for you:

    children = [
      ...
      worker(MemoExample, []),
      ...
    ]
    ...
    supervise children, strategy: ...

If you need to normalize, typecast, map, etc. some of the paramters or the
return value of a memoized function, just create a wrapper function for it.
You can use `defmemop` if you want to hide the non-wrapped version of your
function.

    def age(birth) do
      birth
      |> Timex.parse("{YYYY}-{0M}-{0D}")
      |> age_and_horoscope
      |> pretty_format_age_and_horoscope
    end

    defmemop age_and_horoscope({:ok, date_time}) do
      ...
    end

## Advanced usage

It is possible to manually put values into the cache or ask the cache to forget
certain cached values stored in it.  It's also possible to create a separate
module in the Erlang runtime with the memoized function clauses in it in order
to speed up further calculations.  If you are interested in any of these, have
a look at the functions

* Memoizer.learn/4
* Memoizer.memoized?/3
* Memoizer.forget/1,2,3
* Memoizer.compile/1,2


## How it works

There's a server process started, but the function results are stored in a
protected, read optimized ETS table.  This allows processes to check for
existing results very quickly. `defmemo` wraps the function in some additional
code that makes this checking transparently from the caller process.

The server process is responsible for filling in data to the ETS table and also
for owning the table.  Checking for already existing results happens in the
same process where the function gets called, while putting in new data to the
cache is the responsibility of the server process.

Calling `MemoExample.fib(10)` fills in the ETS table with entries like the
followings.  The tuples contain the function name, the argument list and the
result.

    {{:fib,  [2]},  2}   # MemoExample.fib(2)  ==  2
    {{:fib,  [3]},  3}   # MemoExample.fib(3)  ==  3
    {{:fib,  [4]},  5}   # MemoExample.fib(4)  ==  5
    {{:fib,  [5]},  8}   # MemoExample.fib(5)  ==  8
    {{:fib,  [6]}, 13}   # MemoExample.fib(6)  == 13
    {{:fib,  [7]}, 21}   # MemoExample.fib(7)  == 21
    {{:fib,  [8]}, 34}   # MemoExample.fib(8)  == 34
    {{:fib,  [9]}, 55}   # MemoExample.fib(9)  == 55
    {{:fib, [10]}, 89}   # MemoExample.fib(10) == 89

In memoization implementatios that use GenServers for storing the result cache,
the GenServer can become a bottleneck when all read and write operations go
trough the server process.  In our case `Memoizer` does all writes to the cache
trough a separate gen server process, while read operations happen in the
client processes.  This enables read optimized ETS tables and takes off the
burden of managing the writes from the clients.

In your use case this may be the wrong approach.  It's on my TODO list to add
different store types to Memoizes.  For example, it makes sense sometimes to
store the calcualted values in a DETS or Mnesia table.  In other cases the
simply putting them into the process dictionary is fine.  In other cases ETS
can be the right solution but with a publicly writeable, serverless design.

Please let me know if you need any of these and I'll gladly do them.

