defmodule EXSM do
  @moduledoc """
  Documentation for `EXSM`.
  """

  defmacro __using__(opts) do
    default_transition_values = [:none, :ignore, :reply, :error]
    default_transition_policy = Keyword.get(opts, :default_transition, :reply)
    if not default_transition_policy in default_transition_values do
      raise """
      :default_transition can only be one of #{inspect(default_transition_values)}
      """
    end

    quote do
      alias __MODULE__.EXSMTransitions

      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :states, accumulate: true)
      Module.put_attribute(__MODULE__, :default_transition_policy, unquote(default_transition_policy))
    end
  end

  ### State definition macros

  defmacro state(name, do: block) do
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
    quote do
      defmodule EXSMTransitions do
        import unquote(__MODULE__)

        Module.register_attribute(__MODULE__, :transitions, accumulate: false)

        unquote(block)

        EXSM._inject_transition()
        EXSM._inject_default_transition()

        Module.delete_attribute(__MODULE__, :transitions)
      end
    end
  end

  defmacro state_from <- expression do
    IO.inspect({:from, state_from})
    IO.inspect(expression)

    state_from_ast = Elixir.Macro.escape(state_from)

    expression_keyword = EXSM.Macro.transition_to_keyword(expression)
    IO.inspect(expression_keyword)
    expression_ast = Elixir.Macro.escape(expression_keyword)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "operator <-")

      EXSM._inject_transition()

      Module.register_attribute(__MODULE__, :current_transition_keyword, accumulate: true)
      Module.put_attribute(__MODULE__, :current_transition_keyword,
        {:from, unquote(state_from_ast)})
      Enum.each(unquote(expression_ast), fn {key, value} ->
        Module.put_attribute(__MODULE__, :current_transition_keyword, {key, value})
      end)
    end
  end

  defmacro action(do: expression) do
    IO.inspect({:action, expression})

    expression_ast = Elixir.Macro.escape(expression)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "action")

      Module.put_attribute(__MODULE__, :current_transition_keyword,
        {:action, true})
      Module.put_attribute(__MODULE__, :current_transition_keyword,
        {:action_block, unquote(expression_ast)})
    end
  end

  defmacro action(function) do
    IO.inspect({:action, function})

    function_ast = Elixir.Macro.escape(function)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "action")

      Module.put_attribute(__MODULE__, :current_transition_keyword,
        {:action, true})
      Module.put_attribute(__MODULE__, :current_transition_keyword,
        {:action_function, unquote(function_ast)})
    end
  end

  defmacro _inject_transition() do
    IO.inspect(:_add_transition)

    from_ast = {:unquote, [], [
      quote do
        EXSM.Macro.transition_fstate_from_keyword(
          Module.get_attribute(__MODULE__, :current_transition_keyword)
        )
      end
    ]}

    event_ast = {:unquote, [], [
      quote do
        EXSM.Macro.transition_event_from_keyword(
          Module.get_attribute(__MODULE__, :current_transition_keyword),
          :exsm_event
        )
      end
    ]}

    when_ast = {:unquote, [], [
      quote do
        EXSM.Macro.transition_when_from_keyword(
          Module.get_attribute(__MODULE__, :current_transition_keyword)
        )
      end
    ]}

    action_ast = {:unquote, [], [
      quote do
        EXSM.Macro.transition_action_from_keyword(
          Module.get_attribute(__MODULE__, :current_transition_keyword),
          :state,
          :exsm_event
        )
      end
    ]}

    user_state = {:state, [], nil}

    IO.inspect({:from_ast, from_ast})
    IO.inspect({:event_ast, event_ast})
    IO.inspect({:when_ast, when_ast})
    IO.inspect({:action_ast, action_ast})

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "_inject_transition")

      if Module.has_attribute?(__MODULE__, :current_transition_keyword) do
        def handle_event(unquote(from_ast), unquote(event_ast), unquote(user_state)) when unquote(when_ast) do
          unquote(action_ast)
        end

        Module.delete_attribute(__MODULE__, :current_transition_keyword)
      end
    end
  end

  defmacro _inject_default_transition() do
    IO.inspect(:_inject_default_transition)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "_inject_default_transition")

      case Module.get_attribute(EXSM.Util.parent_module(__MODULE__), :default_transition_policy) do
        :ignore ->
          def handle_event(from, _, state), do: {:noreply, from, state}

        :reply ->
          def handle_event(from, _, state), do: {:reply, from, :no_transition, state}

        :error ->
          def handle_event(_, _, _), do: {:error, :no_transition}

        :none ->
          :ok
      end
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
