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
      import unquote(__MODULE__)

      @before_compile EXSM

      Module.register_attribute(__MODULE__, :states, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :states_meta, accumulate: true)
      Module.register_attribute(__MODULE__, :initial_state, persist: true)
      Module.put_attribute(__MODULE__, :default_transition_policy, unquote(default_transition_policy))
      Module.put_attribute(__MODULE__, :states_meta_defined, false)

      @spec states() :: [EXSM.State.t()]
      def states() do
        EXSM.states(__MODULE__)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      EXSM._inject_states_meta()
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

  # on_enter &Module.function/0
  # on_enter &Module.function/2
  # on_enter do: Module.function()
  # on_enter [user_state: state], do: Module.function(state)
  # on_enter user_state: state, event: event do
  #   Module.function(state, event)
  # end
  defmacro on_enter(opts_or_function, do_block \\ [])

  defmacro on_enter([do: block], []), do: EXSM._on_enter([], do: block)

  defmacro on_enter(opts, do: block) when is_list(opts), do: EXSM._on_enter(opts, do: block)

  defmacro on_enter(function, []) when not is_list(function) do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_enter")

      EXSM.Util.assert_state_function(unquote(function), "on_enter")

      on_enter = EXSM.Util.function_to_arity_2(unquote(function), unquote(Macro.escape(function)))
      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_enter, on_enter})
    end
  end

  def _on_enter(opts, do: block) when is_list(opts) do
    EXSM.Util.assert_only_allowed_keywords(opts, [:user_state, :event], "on_enter")
    user_state_ast = EXSM.Macro.function_param_from_opts(opts, :user_state)
    event_ast = EXSM.Macro.function_param_from_opts(opts, :event)
    function_ast = quote do
      fn unquote(user_state_ast), unquote(event_ast) ->
        unquote(block)
      end
    end

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_enter")

      Module.put_attribute(__MODULE__, :current_state_keyword,
        {:on_enter, unquote(Elixir.Macro.escape(function_ast))}
      )
    end
  end

  # on_leave &Module.function/0
  # on_leave &Module.function/2
  # on_leave do: Module.function()
  # on_leave [user_state: state], do: Module.function(state)
  # on_leave user_state: state, event: event do
  #   Module.function(state, event)
  # end
  defmacro on_leave(opts_or_function, do_block \\ [])

  defmacro on_leave([do: block], []), do: EXSM._on_leave([], do: block)

  defmacro on_leave(opts, do: block) when is_list(opts), do: EXSM._on_leave(opts, do: block)

  defmacro on_leave(function, []) when not is_list(function) do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_leave")

      EXSM.Util.assert_state_function(unquote(function), "on_leave")

      on_leave = EXSM.Util.function_to_arity_2(unquote(function), unquote(Macro.escape(function)))
      Module.put_attribute(__MODULE__, :current_state_keyword, {:on_leave, on_leave})
    end
  end

  def _on_leave(opts, do: block) when is_list(opts) do
    EXSM.Util.assert_only_allowed_keywords(opts, [:user_state, :event], "on_leave")
    user_state_ast = EXSM.Macro.function_param_from_opts(opts, :user_state)
    event_ast = EXSM.Macro.function_param_from_opts(opts, :event)
    function_ast = quote do
      fn unquote(user_state_ast), unquote(event_ast) ->
        unquote(block)
      end
    end

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "on_leave")

      Module.put_attribute(__MODULE__, :current_state_keyword,
        {:on_leave, unquote(Elixir.Macro.escape(function_ast))}
      )
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
    quote unquote: false do
      if not Module.get_attribute(__MODULE__, :states_meta_defined) do
        states_meta =
          Module.get_attribute(__MODULE__, :states_meta)
          |> Enum.map(fn {_, %EXSM.Macro.State{} = state_meta} -> state_meta end)

        defmodule EXSMStatesMeta do

          for %EXSM.Macro.State{id: id, state: %EXSM.State{name: name}} <- states_meta do
            def _exsm_find_id(unquote(Elixir.Macro.escape(name))) do
              {:ok, unquote(id)}
            end
          end

          def _exsm_find_id(_) do
            {:error, :not_found}
          end

          for %EXSM.Macro.State{state: %EXSM.State{} = state} = meta_state <- states_meta do
            %EXSM.Macro.State{id: id, on_enter: on_enter, on_leave: on_leave} = meta_state

            def unquote(id)(:state) do
              unquote(Elixir.Macro.escape(state))
            end

            def unquote(id)(:on_enter) do
              unquote(on_enter)
            end

            def unquote(id)(:on_leave) do
              unquote(on_leave)
            end
          end
        end

        Module.put_attribute(__MODULE__, :states_meta_defined, true)
      end
    end
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

    state_to = Keyword.fetch!(expression_keyword, :to)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "operator <-")

      states = Module.get_attribute(EXSM.Util.parent_module(__MODULE__), :states_meta)
      EXSM.Macro.assert_state_exists(unquote(state_from), states)
      EXSM.Macro.assert_state_exists(unquote(state_to), states)

      EXSM._inject_transition()

      Module.register_attribute(__MODULE__, :current_transition_keyword, accumulate: true)
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:from, unquote(state_from_ast)})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:from_value, unquote(state_from)})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:to_value, unquote(state_to)})
      Enum.each(unquote(expression_ast), fn {key, value} ->
        Module.put_attribute(__MODULE__, :current_transition_keyword, {key, value})
      end)
    end
  end

  defmacro action([user_state: _] = opts, do: expression), do: EXSM._action(opts, do: expression)

  defmacro action(do: expression), do: EXSM._action([], do: expression)

  defmacro action(function) do
    function_ast = Elixir.Macro.escape(function)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "action")

      action = EXSM.Util.function_to_arity_2(unquote(function), unquote(function_ast))
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action, true})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action_function, action})
    end
  end

  def _action(opts, do: expression) do
    EXSM.Util.assert_only_allowed_keywords(opts, [:user_state], "action")
    EXSM.Macro.assert_action_variables(expression)
    expression_ast = Elixir.Macro.escape(expression)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "action")

      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action, true})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action_block, unquote(expression_ast)})
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
        states = Module.get_attribute(EXSM.Util.parent_module(__MODULE__), :states_meta)
        action_ast = EXSM.Macro.transition_action_from_keyword(transition_keyword, :state, :exsm_event, states)
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
    initial_states =
      get_initial_states(module, opts)
      |> Enum.map(fn %EXSM.State{name: name} = state ->
        case EXSM.Util.state_id_by_name(module, name) do
          {:ok, state_id} ->
            {state_id, state}

          {:error, :not_found} ->
            raise """
            Metadata for state #{inspect(name)} not found
            in module #{module}
            """
        end
      end)
    state_machine = EXSM.StateMachine.new(module, initial_states, opts)
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

  defp get_initial_states(module, opts) do
    case Keyword.get(opts, :initial_states) do
      nil ->
        initial_states =
          module.__info__(:attributes)
          |> Keyword.get_values(:initial_states)
        if initial_states == [] do
          raise """
          Initial state for SM should be provided in options to
          __MODULE__.new() if there is no initial state declared like:
          state :empty do
            initial true
          end
          """
        end
        initial_states

      initial_states_names when is_list(initial_states_names) and length(initial_states_names) > 0 ->
        names_set = MapSet.new(initial_states_names)
        initial_states =
          EXSM.states(module)
          |> Enum.filter(fn %EXSM.State{name: name} ->
            MapSet.member?(names_set, name)
          end)
        if initial_states == [] do
          raise """
          No states #{inspect(initial_states_names)} exist
          for module #{module}
          """
        end
        states_not_found =
          MapSet.difference(
            names_set,
            MapSet.new(initial_states, &(&1.name))
          )
          |> MapSet.to_list()
        if states_not_found != [] do
          raise """
          States #{inspect(states_not_found)} do not exist
          for module #{module}
          """
        end
        initial_states
    end
  end

  defp enter_all_states(module, state_ids, user_state) do
    Enum.reduce_while(state_ids, {[], user_state}, fn state_id, {entered_states, acc_user_state} ->
      try do
        on_enter = EXSM.Util.on_enter_by_id(module, state_id)
        case EXSM.Util.enter_state(on_enter, acc_user_state) do
          {:noreply, new_user_state} ->
            {:cont, {[state_id | entered_states], new_user_state}}

          {:error, _} = error ->
            unroll_states(module, entered_states, acc_user_state, true)
            {:halt, error}
        end
      catch
        e ->
          unroll_states(module, entered_states, acc_user_state, false)
          reraise e, __STACKTRACE__
      end
    end)
    |> then(fn
      {:error, _} = error ->
        error

      {ids, new_user_state} when is_list(ids) ->
        {:ok, new_user_state}
    end)
  end

  defp unroll_states(module, state_ids, user_state, do_reraise \\ false) do
    Enum.reduce_while(state_ids, user_state, fn state_id, acc_user_state ->
      try do
        on_leave = EXSM.Util.on_leave_by_id(module, state_id)
        case EXSM.Util.leave_state(on_leave, acc_user_state) do
          {:noreply, new_user_state} ->
            {:cont, new_user_state}

          {:error, error} ->
            Logger.error """
            Error unrolling states occur #{inspect(error)},
            ignoring it as another error is about to be returned
            """
            {:halt, acc_user_state}
        end
      catch
        exception ->
          if do_reraise do
            reraise exception, __STACKTRACE__
          else
            Logger.error Exception.format_banner(:error, exception)
          end
          {:halt, acc_user_state}
      end
    end)
  end
end
