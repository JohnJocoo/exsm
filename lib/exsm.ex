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
      Module.register_attribute(__MODULE__, :states_meta, accumulate: true)
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

      %EXSM.Macro.State{state: state} = state_meta = EXSM.Macro.state_from_keyword(
        unquote(name),
        Module.delete_attribute(__MODULE__, :current_state_keyword),
        length(Module.get_attribute(__MODULE__, :states_meta))
      )
      Module.put_attribute(__MODULE__, :states_meta, {unquote(name), state_meta})
      Module.put_attribute(__MODULE__, :states, state)
      EXSM._put_initial_state()
    end
  end

  defmacro state(name) do
    quote do
      %EXSM.Macro.State{state: state} = state_meta = EXSM.Macro.state_from_keyword(
        unquote(name),
        [],
        length(Module.get_attribute(__MODULE__, :states_meta))
      )
      Module.put_attribute(__MODULE__, :states_meta, {unquote(name), state_meta})
      Module.put_attribute(__MODULE__, :states, state)
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
    function_ast = quote do
      fn state, event ->
        _user_state_unused = state
        _exsm_event_unused = event
        unquote(block)
      end
    end

    quote bind_quoted: [function_ast: function_ast] do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_enter")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_enter, function_ast})
    end
  end

  defmacro on_enter(function) do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_enter")

      EXSM.Util.assert_state_function(unquote(function), "on_enter")

      on_enter = EXSM.Util.function_to_arity_2(unquote(function), unquote(Macro.escape(function)))
      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_enter, on_enter})
    end
  end

  defmacro on_leave(do: block) do
    function_ast = quote do
      fn state, event ->
        _user_state_unused = state
        _exsm_event_unused = event
        unquote(block)
      end
    end

    quote bind_quoted: [function_ast: function_ast] do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_leave")

      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_leave, function_ast})
    end
  end

  defmacro on_leave(function) do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_leave")

      EXSM.Util.assert_state_function(unquote(function), "on_leave")

      on_leave = EXSM.Util.function_to_arity_2(unquote(function), unquote(Macro.escape(function)))
      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_leave, on_leave})
    end
  end

  defmacro _put_initial_state() do
    quote do
      states = Module.get_attribute(__MODULE__, :states)
      if  states != nil and states != [] and List.first(states).initial? do
        initial_state = Module.get_attribute(__MODULE__, :initial_state)
        if initial_state == nil do
          Module.put_attribute(__MODULE__, :initial_state, List.first(states))
        else
          raise """
          Only one state can be marked as initial.
          First state #{inspect(initial_state)}
          Second #{inspect(List.first(states))}
          """
        end
      end
    end
  end

  defmacro _inject_states_meta() do
#    quote do
#      states_meta = Module.get_attribute(__MODULE__, :states_meta)
#
#      defmodule EXSMStatesMeta do
#
#        for %EXSM.Macros.State{id: id, state: %EXSM.State{name: name}} <- states_meta do
#
#        end
#
#      end
#    end
  end

  ### Transition table definition macros

  defmacro transitions(do: block) do
    quote do
      EXSM._inject_states_meta()

      defmodule EXSMTransitions do
        import unquote(__MODULE__)

        Module.put_attribute(__MODULE__, :transitions, true)

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

      states = Module.get_attribute(EXSM.Util.parent_module(__MODULE__), :states_meta)
      EXSM.Macro.assert_state_exists(unquote(state_from), states)

      EXSM._inject_transition()

      Module.register_attribute(__MODULE__, :current_transition_keyword, accumulate: true)
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:from, unquote(state_from_ast)})
      Enum.each(unquote(expression_ast), fn {key, value} ->
        if key == :to do
          EXSM.Macro.assert_state_exists(value, states)
        end
        Module.put_attribute(__MODULE__, :current_transition_keyword, {key, value})
      end)
    end
  end

  defmacro action(do: expression) do
    EXSM.Macro.assert_action_variables(expression)
    expression_ast = Elixir.Macro.escape(expression)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "action")

      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action, true})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action_block, unquote(expression_ast)})
    end
  end

  defmacro action(function) do
    function_ast = Elixir.Macro.escape(function)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "action")

      action = EXSM.Util.function_to_arity_2(unquote(function), unquote(function_ast))
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action, true})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action_function, action})
    end
  end

  defmacro _inject_transition() do
    quote unquote: false do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "_inject_transition")

      transition_keyword = Module.delete_attribute(__MODULE__, :current_transition_keyword)

      if transition_keyword != nil do
        from_ast = EXSM.Macro.transition_fstate_from_keyword(transition_keyword)
        event_ast = EXSM.Macro.transition_event_from_keyword(transition_keyword, :exsm_event)
        when_ast = EXSM.Macro.transition_when_from_keyword(transition_keyword)
        action_ast = EXSM.Macro.transition_action_from_keyword(transition_keyword, :state, :exsm_event)
        user_state = {:state, [], nil}

        def handle_event(unquote(from_ast), unquote(event_ast), unquote(user_state)) when unquote(when_ast) do
          unquote(action_ast)
        end
      end
    end
  end

  defmacro _inject_default_transition() do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "_inject_default_transition")

      case Module.get_attribute(EXSM.Util.parent_module(__MODULE__), :default_transition_policy) do
        :none ->
          :ok

        :ignore ->
          def handle_event(_, _, _), do: {:no_transition, :ignore}

        :reply ->
          def handle_event(_, _, _), do: {:no_transition, :reply}

        :error ->
          def handle_event(_, _, _), do: {:no_transition, :error}
      end
    end
  end

  ### Public functions

  @spec states(module()) :: [EXSM.State.t()]
  def states(module) do
    module.__info__(:attributes)
    |> Keyword.get_values(:states)
    |> List.flatten()
  end

  @spec new(module(), Keyword.t()) :: EXSM.StateMachine.t() | {:error, any()}
  def new(module, opts \\ []) do
    initial_state = %EXSM.State{name: initial_state_name} = get_initial_state(module, opts)
    state_machine = EXSM.StateMachine.new(module, initial_state, opts)
    case EXSM.Util.enter_state(
           module,
           initial_state_name,
           EXSM.StateMachine.user_state(state_machine)) do
      {:noreply, user_state} ->
        EXSM.StateMachine.update_user_state(state_machine, user_state)

      {:error, _} = error ->
        error
    end
  end

  defp get_initial_state(module, opts) do
    case Keyword.get(opts, :initial_state) do
      nil ->
        initial_state =
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

      initial_state_name ->
        initial_state =
          EXSM.states(module)
          |> Enum.find(fn
            %EXSM.State{name: ^initial_state_name} -> true
            _ -> false
          end)
        if initial_state == nil do
          raise """
          No state #{inspect(initial_state_name)} exists
          for module #{module}
          """
        end
        initial_state
    end
  end
end
