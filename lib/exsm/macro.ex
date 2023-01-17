defmodule EXSM.Macro do
  @moduledoc false

  # after user module definition done inject states meta info

  defmacro __before_compile__(_env) do
    quote do
      EXSM.Macro._inject_states_meta()
    end
  end

  ### Common definition macros

  defmacro describe(info) do
    quote do
      attribute =
        cond do
          Module.has_attribute?(__MODULE__, :current_state_keyword) ->
            :current_state_keyword

          Module.has_attribute?(__MODULE__, :current_region_keyword) ->
            :current_region_keyword

          true ->
            raise """
            describe can only be defined within region or state block"
            Example:
            state do
              describe ...
            end
            """
        end

      Module.put_attribute(__MODULE__, attribute, {:description, unquote(info)})
    end
  end

  ### Region definition macros

  defmacro region(name, do: block) when is_atom(name) do
    quote do
      Module.register_attribute(__MODULE__, :current_region_keyword, accumulate: true)
      Module.put_attribute(__MODULE__, :region_name, unquote(name))

      unquote(block)

      %EXSM.Region{} = region = EXSM.Macro.region_from_keyword(
        unquote(name),
        Module.delete_attribute(__MODULE__, :current_region_keyword)
      )
      Module.delete_attribute(__MODULE__, :region_name)
      Module.put_attribute(__MODULE__, :regions, region)
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
        length(Module.get_attribute(__MODULE__, :states_meta)),
        Module.get_attribute(__MODULE__, :region_name)
      )
      Module.put_attribute(__MODULE__, :states_meta, {unquote(name), state_meta})
      Module.put_attribute(__MODULE__, :states, state)
      EXSM.Macro._put_initial_state()
    end
  end

  defmacro state(name) do
    quote do
      %EXSM.Macro.State{state: state} = state_meta = EXSM.Macro.state_from_keyword(
        unquote(name),
        [],
        length(Module.get_attribute(__MODULE__, :states_meta)),
        Module.get_attribute(__MODULE__, :region_name)
      )
      Module.put_attribute(__MODULE__, :states_meta, {unquote(name), state_meta})
      Module.put_attribute(__MODULE__, :states, state)
      EXSM.Macro._put_initial_state()
    end
  end

  defmacro initial(true) do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "initial")
      Module.put_attribute(__MODULE__, :current_state_keyword, {:initial?, true})
    end
  end

  defmacro initial(false) do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "initial")
    end
  end

  defmacro terminal(true) do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "terminal")
      Module.put_attribute(__MODULE__, :current_state_keyword, {:terminal?, true})
    end
  end

  defmacro terminal(false) do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :current_state_keyword, "state", "terminal")
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

  defmacro on_enter([do: block], []), do: EXSM.Macro._on_enter([], do: block)

  defmacro on_enter(opts, do: block) when is_list(opts), do: EXSM.Macro._on_enter(opts, do: block)

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
        {:on_enter, unquote(Macro.escape(function_ast))}
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

  defmacro on_leave([do: block], []), do: EXSM.Macro._on_leave([], do: block)

  defmacro on_leave(opts, do: block) when is_list(opts), do: EXSM.Macro._on_leave(opts, do: block)

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
        {:on_leave, unquote(Macro.escape(function_ast))}
      )
    end
  end

  defmacro _put_initial_state() do
    quote do
      states = Module.get_attribute(__MODULE__, :states)
      if  states != nil and states != [] and List.first(states).initial? do
        %EXSM.State{region: region} = state = List.first(states)
        initial_state_region =
          Module.get_attribute(__MODULE__, :initial_states)
          |> Enum.find(fn %EXSM.State{region: initial_region} -> initial_region == region end)
        if initial_state_region == nil do
          Module.put_attribute(__MODULE__, :initial_states, state)
        else
          raise """
          Only one state can be marked as initial.
          First state #{inspect(initial_state_region.name)}
          Second #{inspect(state.name)}
          """
        end
      end
    end
  end

  defmacro _inject_states_meta() do
    quote unquote: false do
      if not Module.get_attribute(__MODULE__, :states_meta_defined) do
        repeted_states =
          Module.get_attribute(__MODULE__, :states)
          |> Enum.map(fn %EXSM.State{name: name} -> name end)
          |> Enum.frequencies()
          |> Enum.filter(fn {_, frequency} -> frequency > 1 end)
          |> Enum.map(fn {name, _} -> name end)

        if repeted_states != [] do
          raise """
          There are duplicated states in module #{__MODULE__}:
          #{inspect(repeted_states)}
          """
        end

        states_meta =
          Module.get_attribute(__MODULE__, :states_meta)
          |> Enum.map(fn {_, %EXSM.Macro.State{} = state_meta} -> state_meta end)

        defmodule EXSMStatesMeta do

          for %EXSM.Macro.State{id: id, state: %EXSM.State{name: name}} <- states_meta do
            def _exsm_find_id(unquote(Macro.escape(name))) do
              {:ok, unquote(id)}
            end
          end

          def _exsm_find_id(_) do
            {:error, :not_found}
          end

          for %EXSM.Macro.State{state: %EXSM.State{} = state} = meta_state <- states_meta do
            %EXSM.Macro.State{id: id, on_enter: on_enter, on_leave: on_leave} = meta_state

            def unquote(id)(:state) do
              unquote(Macro.escape(state))
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
      EXSM.Macro._inject_states_meta()

      defmodule EXSMTransitions do
        import unquote(__MODULE__)

        Module.put_attribute(__MODULE__, :transitions, true)

        unquote(block)

        EXSM.Macro._inject_transition()
        EXSM.Macro._inject_default_transition()

        Module.delete_attribute(__MODULE__, :transitions)
      end
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
        action_ast = EXSM.Macro.transition_action_from_keyword(transition_keyword, :exsm_event, states)
        user_state_ast = EXSM.Macro.transition_user_state_from_keyword(transition_keyword)

        def handle_event(unquote(from_ast), unquote(event_ast), unquote(user_state_ast)) when unquote(when_ast) do
          unquote(action_ast)
        end
      end
    end
  end

  defmacro _inject_default_transition() do
    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "_inject_default_transition")

      case Module.get_attribute(EXSM.Util.parent_module(__MODULE__), :default_transition_policy) do
        :no_function_match ->
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

  # helper functions

  def state_from_keyword(name, keyword, seq_number, region) do
    assert_no_duplicate_keys(name, keyword, "State")

    %EXSM.Macro.State{
      state: %EXSM.State{
        name: name,
        description: Keyword.get(keyword, :description),
        initial?: Keyword.get(keyword, :initial?, false),
        terminal?: Keyword.get(keyword, :terminal?, false),
        region: region
      },
      id: make_state_id(name, seq_number),
      on_enter: Keyword.get(keyword, :on_enter),
      on_leave: Keyword.get(keyword, :on_leave)
    }
  end

  def region_from_keyword(name, keyword) do
    assert_no_duplicate_keys(name, keyword, "Region")

    %EXSM.Region{
      name: name,
      description: Keyword.get(keyword, :description)
    }
  end

  def transition_to_keyword(expression) do
    parsed = parse_transition(expression, [])

    has_duplicate_keys =
      Enum.group_by(parsed, &elem(&1, 0), &elem(&1, 1))
      |> Enum.any?(fn {_, elements} -> length(elements) > 1 end)

    if has_duplicate_keys do
      ops_dbg = %{
        to: ">>>",
        when: "when",
        ast_eq: "="
      }

      statements = Enum.map(parsed, fn {key, _} -> Map.get(ops_dbg, key, key) end)

      raise """
      Transition has duplicate statements
      #{inspect(statements)}
      """
    end

    assert_has_keyword(parsed, :to, "transition", ">>> dest_state",
      ":stopped <- :play >>> :playing")

    if Keyword.has_key?(parsed, :ast_eq) do
      assert_has_keyword(parsed, :left_to, "transition", ">>> dest_state",
        ":stopped <- :play = event >>> :playing")

      {event_right, result} = Keyword.pop!(parsed, :left_to)
      {{op, meta, [event_left, _]}, result} = Keyword.pop!(result, :ast_eq)
      [{:event, {op, meta, [event_left, event_right]}} | result]
    else
      assert_has_keyword(parsed, :left_to, "transition", ">>> dest_state",
        ":stopped <- :play >>> :playing")

      {event, result} = Keyword.pop!(parsed, :left_to)
      [{:event, event} | result]
    end
  end

  def transition_fstate_from_keyword(keyword) do
    assert_has_keyword(keyword, :from, "transition", "source_state <- event",
      ":stopped <- :play >>> :playing")

    Keyword.fetch!(keyword, :from)
  end

  def transition_event_from_keyword(keyword, event_param) do
    assert_has_keyword(keyword, :event, "transition", "source_state <- event",
      ":stopped <- :play >>> :playing")

    event = Keyword.fetch!(keyword, :event)

    if Keyword.has_key?(keyword, :action_function) do
      {:=, [], [event, {event_param, [], nil}]}
    else
      event
    end
  end

  def transition_when_from_keyword(keyword) do
    if Keyword.has_key?(keyword, :when) do
      Keyword.fetch!(keyword, :when)
    else
      :true
    end
  end

  def transition_action_from_keyword(keyword, event_param, states_meta) do
    assert_has_keyword(keyword, :to, "transition", ">>> dest_state",
      ":stopped <- :play >>> :playing")
    state_from = Keyword.fetch!(keyword, :from)
    from_value = Keyword.fetch!(keyword, :from_value)
    %EXSM.Macro.State{id: id_from} = Enum.find_value(states_meta, fn
      {^from_value, value} -> value
      _ -> false
    end)
    state_to = Keyword.fetch!(keyword, :to)
    to_value = Keyword.fetch!(keyword, :to_value)
    %EXSM.Macro.State{id: id_to} = Enum.find_value(states_meta, fn
      {^to_value, value} -> value
      _ -> false
    end)

    if Keyword.has_key?(keyword, :action) do
      quote do
        unquote(inject_action(keyword, event_param))

        {:transition, {
          {unquote(state_from), unquote(id_from)},
          {unquote(state_to), unquote(id_to)},
          exsm_action
        }}
      end
    else
      quote do
        {:transition, {
          {unquote(state_from), unquote(id_from)},
          {unquote(state_to), unquote(id_to)},
          nil
        }}
      end
    end
  end

  def transition_user_state_from_keyword(transition_keyword) do
    transition_keyword
    |> Keyword.get(:when_opts, [])
    |> Keyword.get(:user_state, nil)
    |> then(fn
         nil -> {:_, [], nil}
         name -> name
       end)
  end

  def assert_in_block(module, attribute, block_name, current_function) do
    if not Module.has_attribute?(module, attribute) do
      raise """
      #{current_function} can only be defined within #{block_name} block"
      Example:
      #{block_name} do
        #{current_function} ...
      end
      """
    end
  end

  def assert_action_variables(block_ast) do
    assert_block_variables(
      block_ast,
      [:exsm_event, :exsm_action],
      "action"
    )
  end

  def assert_guard_variables(block_ast) do
    assert_block_variables(
      block_ast,
      [:exsm_event],
      "guard"
    )
  end

  def assert_block_variables(block_ast, restricted_vars, block_type)

  def assert_block_variables({:^, _, [{_, _, nil}]}, _, _), do: :ok

  def assert_block_variables({var, _, nil}, restricted_vars, block_type) do
    if var in restricted_vars do
      raise """
      #{var} variable name is reserved for #{block_type} block
      """
    end
    :ok
  end

  def assert_block_variables({_, _, args}, restricted_vars, block_type) do
    Enum.each(args, fn expression ->
      assert_block_variables(expression, restricted_vars, block_type)
    end)
  end

  def assert_block_variables(_, _, _), do: :ok

  def assert_state_exists(state_name, states) do
    if not Enum.any?(states, fn {key, _} -> key == state_name end) do
      raise """
      State #{inspect(state_name)} not found in declared states,
      please be sure it was declared before transitions block, ex.:
        state #{inspect(state_name)}
      """
    end
  end

  def function_param_from_opts(opts, name) do
    case Keyword.get(opts, name) do
      nil -> {:_, [], nil}
      ast -> ast
    end
  end

  defp make_state_id(name, _) when is_atom(name) do
    name
  end

  defp make_state_id(name, _) when is_binary(name) do
    String.to_atom(name)
  end

  defp make_state_id(_, seq_number) do
    String.to_atom("_exsm_state_#{seq_number}")
  end

  defp parse_transition({:>>>, _, [left, to]}, acc) do
    [{:left_to, left} | [{:to, to} | acc]]
  end

  defp parse_transition({:when, _, [left, guard_definition]}, acc) do
    {guard, guard_opts} = parse_guard(guard_definition)
    assert_guard_variables(guard)
    parse_transition(left, [{:when_opts, guard_opts} | [{:when, guard} | acc]])
  end

  defp parse_transition({:=, _, [_, right]} = ast, acc) do
    parse_transition(right, [{:ast_eq, ast} | acc])
  end

  defp parse_transition({op, meta, args}, _) when is_list(args) do
    raise """
    Unknown operator or statement #{inspect(op)}
    With args #{inspect(args)}
    """, meta
  end

  defp parse_guard({:|>, _, [opts, guard_part]}) when is_list(opts) do
    {guard_part, opts}
  end

  defp parse_guard({op, meta, nil}) do
    {{op, meta, nil}, []}
  end

  defp parse_guard({op, meta, args}) do
    {filtered_args, opts} = Enum.reduce(args, {[], []},
      fn arg, {args_acc, opts_acc} ->
        {guard_part, opts} = parse_guard(arg)
        {[guard_part | args_acc], opts ++ opts_acc}
      end)
    {{op, meta, Enum.reverse(filtered_args)}, opts}
  end

  defp parse_guard(other) do
    {other, []}
  end

  defp inject_action(keyword, event_param) do
    if Keyword.has_key?(keyword, :action_function) do
      inject_action_function(keyword, event_param)
    else
      inject_action_block(keyword)
    end
  end

  defp inject_action_function(keyword, event_param) do
    quote do
      exsm_action = fn user_state ->
        _function = unquote(Keyword.fetch!(keyword, :action_function))
        _function.(
          user_state,
          unquote({event_param, [], nil})
        )
      end
    end
  end

  defp inject_action_block(keyword) do
    quote do
      exsm_action = fn unquote(Keyword.fetch!(keyword, :action_user_state)) ->
        unquote(Keyword.fetch!(keyword, :action_block))
      end
    end
  end

  defp assert_has_keyword(keyword, key, scope, statement, example) do
    if not Keyword.has_key?(keyword, key) do
      raise """
      #{statement} is required in #{scope}
      Example:
      #{example}
      """
    end
  end

  defp assert_no_duplicate_keys(name, keyword, place) do
    has_duplicate_keys =
      Enum.group_by(keyword, &elem(&1, 0), &elem(&1, 1))
      |> Enum.any?(fn {_, elements} -> length(elements) > 1 end)

    if has_duplicate_keys do
      raise """
      #{place} #{name} has duplicate attributes
      #{inspect(Enum.map(keyword, &elem(&1, 0)))}
      """
    end
  end
end
