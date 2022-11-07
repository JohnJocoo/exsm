defmodule EXSM do
  @moduledoc """
  Documentation for `EXSM`.
  """

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :states, accumulate: true)
      Module.register_attribute(__MODULE__, :transitions, accumulate: true)
    end
  end

  ### State definition macros

  defmacro state(name, do: block) do
    IO.inspect({:state, name, block})
    quote do
      Module.register_attribute(__MODULE__, :current_state_keyword, accumulate: true)

      unquote(block)

      Module.put_attribute(__MODULE__, :states,
        {unquote(name),
          EXSM.Macro.from_keyword(unquote(name),
                                  Module.get_attribute(__MODULE__, :current_state_keyword))}
      )
      Module.delete_attribute(__MODULE__, :current_state_keyword)
    end
  end

  defmacro state(name) do
    IO.inspect({:state, name})
    quote do
      Module.put_attribute(__MODULE__, :states,
          {unquote(name),
            EXSM.Macro.from_keyword(unquote(name), [])}
      )
    end
  end

  defmacro describe(info) do
    IO.inspect({:describe, info})

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "describe")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:description, unquote(info)})
    end
  end

  defmacro initial(true) do
    quote do
      Module.put_attribute(__MODULE__, :current_state_keyword, {:initial?, true})
    end
  end

  defmacro initial(false) do
    quote do
    end
  end

  defmacro on_enter(do: block) do
    IO.inspect({:on_enter, block})

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_enter")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_enter,
        fn state, event ->
          unquote(block)
        end
      })
    end
  end

  defmacro on_enter(function) do
    IO.inspect({:on_enter, function})

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_enter")

      EXSM.Util.assert_state_function(unquote(function), "on_enter")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_enter,
        EXSM.Util.function_to_arity_2(unquote(function))}
      )
    end
  end

  defmacro on_leave(do: block) do
    IO.inspect({:on_leave, block})

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_leave")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_leave,
        fn state, event ->
          unquote(block)
        end
      })
    end
  end

  defmacro on_leave(function) do
    IO.inspect({:on_leave, function})

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_leave")

      EXSM.Util.assert_state_function(unquote(function), "on_leave")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_leave,
        EXSM.Util.function_to_arity_2(unquote(function))}
      )
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
