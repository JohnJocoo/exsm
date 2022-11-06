defmodule EXSM do
  @moduledoc """
  Documentation for `EXSM`.
  """

  defmacro __using__(opts) do
    quote do
      import unquote(__MODULE__)
    end
  end

  ### State definition macros

  defmacro state(name, do: block) do
    IO.inspect({:state, name, block})
    quote do

    end
  end

  defmacro state(name) do
    IO.inspect({:state, name})
    quote do

    end
  end

  defmacro describe(info) do
    IO.inspect({:describe, info})
    quote do

    end
  end

  defmacro on_enter(do: block) do
    IO.inspect({:on_enter, block})
    quote do

    end
  end

  defmacro on_enter(function) do
    IO.inspect({:on_enter, function})
    quote do

    end
  end

  defmacro on_leave(do: block) do
    IO.inspect({:on_leave, block})
    quote do

    end
  end

  defmacro on_leave(function) do
    IO.inspect({:on_leave, function})
    quote do

    end
  end

  ### Transition table definition macros

  defmacro transitions(do: block) do
    IO.inspect({:transitions, block})
    quote do

    end
  end

  defmacro state_from <- expression do
    IO.inspect({:from, state_from})
    IO.inspect(expression)
    quote do

    end
  end

  defmacro action(do: expression) do
    IO.inspect(expression)
    quote do

    end
  end

  defmacro action(function) do
    IO.inspect(function)
    quote do

    end
  end

  @doc """
  Hello world.

  ## Examples

      iex> EXSM.hello()
      :world

  """
  def hello do
    :world
  end
end
