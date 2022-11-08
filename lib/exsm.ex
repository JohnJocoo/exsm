defmodule EXSM do
  @moduledoc """
  Documentation for `EXSM`.
  """

  defmacro __using__(_opts) do
    quote do
      alias __MODULE__.EXSMTransitions

      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :states, accumulate: true)
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
          EXSM.Macro.state_from_keyword(unquote(name),
            Module.delete_attribute(__MODULE__, :current_state_keyword))
        }
      )
    end
  end

  defmacro state(name) do
    IO.inspect({:state, name})
    quote do
      Module.put_attribute(__MODULE__, :states,
          {unquote(name),
            EXSM.Macro.state_from_keyword(unquote(name), [])}
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
      defmodule EXSMTransitions do
        Module.register_attribute(__MODULE__, :transitions, accumulate: true)

        unquote(block)

        Module.put_attribute(__MODULE__, :transitions,
          EXSM.Macro.transition_ast_from_keyword(
            Module.delete_attribute(__MODULE__, :current_transition_keyword)
          )
        )

        IO.inspect(@transitions)
      end
    end
  end

  defmacro state_from <- expression do
    IO.inspect({:from, state_from})
    IO.inspect(expression)

    expression_keyword = EXSM.Macro.transition_right_expression_to_keyword(expression, state_from)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "operator <-")

      Module.put_attribute(__MODULE__, :transitions,
        EXSM.Macro.transition_ast_from_keyword(
          Module.delete_attribute(__MODULE__, :current_transition_keyword)
        )
      )

      Module.register_attribute(__MODULE__, :current_transition_keyword, accumulate: true)
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:from, unquote(state_from)})
      Enum.each(unquote(expression_keyword), fn {key, value} ->
        Module.put_attribute(__MODULE__, :current_transition_keyword, {key, value})
      end)
    end
  end

  defmacro action(do: expression) do
    IO.inspect({:action, expression})
    quote do

    end
  end

  defmacro action(function) do
    IO.inspect({:action, function})
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
