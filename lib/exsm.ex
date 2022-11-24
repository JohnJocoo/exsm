defmodule EXSM do
  @moduledoc """
  Documentation for `EXSM`.
  """

  defmacro __using__(opts) do
    default_transition_values = [:none, :ignore, :reply, :error]
    default_transition_policy = Keyword.get(opts, :default_transition, :reply)

    if default_transition_policy not in default_transition_values do
      raise """
      :default_transition can only be one of #{inspect(default_transition_values)}
      """
    end

    quote do
      alias __MODULE__.EXSMTransitions

      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :states, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :initial_state, persist: true)
      Module.put_attribute(__MODULE__, :default_transition_policy, unquote(default_transition_policy))

      @spec states() :: [EXSM.State.t()]
      def states() do
        EXSM.states(__MODULE__)
      end
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
      EXSM._put_initial_state()
    end
  end

  defmacro state(name) do
    quote do
      Module.put_attribute(__MODULE__, :states,
          {unquote(name),
            EXSM.Macro.state_from_keyword(unquote(name), [])}
      )
      EXSM._put_initial_state()
    end
  end

  defmacro describe(info) do
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
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_enter")

      EXSM.Util.assert_state_function(unquote(function), "on_enter")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_enter,
        EXSM.Util.function_to_arity_2(unquote(function))}
      )
    end
  end

  defmacro on_leave(do: block) do
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
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_leave")

      EXSM.Util.assert_state_function(unquote(function), "on_leave")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_leave,
        EXSM.Util.function_to_arity_2(unquote(function))}
      )
    end
  end

  defmacro _put_initial_state() do
    quote do
      if Module.get_attribute(__MODULE__, :states) != nil and
         Module.get_attribute(__MODULE__, :states) != [] and
         EXSM.Macro.initial_state?(List.first(Module.get_attribute(__MODULE__, :states))) do
           if Module.get_attribute(__MODULE__, :initial_state) == nil do
             Module.put_attribute(__MODULE__, :initial_state,
               elem(List.first(Module.get_attribute(__MODULE__, :states)), 1).state)
           else
             raise """
             Only one state can be marked as initial.
             First state #{Module.get_attribute(__MODULE__, :initial_state)}
             Second #{List.first(Module.get_attribute(__MODULE__, :states))}
             """
           end
         end
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
    state_from_ast = Elixir.Macro.escape(state_from)

    expression_keyword = EXSM.Macro.transition_to_keyword(expression)
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

  ### Public functions

  @spec states(module()) :: [EXSM.State.t()]
  def states(module) do
    module.__info__(:attributes)
    |> Keyword.get_values(:states)
    |> List.flatten()
    |> Enum.map(fn {_, %EXSM.Macro.State{state: %EXSM.State{} = state}} -> state end)
  end

  @spec new(module(), Keyword.t()) :: EXSM.StateMachine.t()
  def new(module, opts \\ []) do
    initial_state = get_initial_state(module, opts)
    EXSM.StateMachine.new(module, initial_state, opts)
  end

  defp get_initial_state(module, opts) do
    case Keyword.get(:initial_state) do
      nil ->
        %EXSM.State{name: initial_state} =
          module.__info__(:attributes)
          |> Keyword.get(:initial_state)
        if initial_state == nil do
          raise """
          Initial state for SM should be provided in options to
          __MODULE__.new() if there is no initial state declared like:
          state :empty do
            initial true
          end
          """
        end
        initial_state

      initial_state ->
        initial_state
    end
  end
end
