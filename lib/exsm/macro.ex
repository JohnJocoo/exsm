defmodule EXSM.Macro do
  @moduledoc false

  @type ast :: tuple()

  defmodule State do

    @type t :: %__MODULE__{
                 state: EXSM.State.t(),
                 on_enter: EXSM.Macro.ast() | nil,
                 on_leave: EXSM.Macro.ast() | nil,
                 id: atom()
               }
    defstruct [:state, :on_enter, :on_leave, :id]
  end

  def state_from_keyword(name, keyword, seq_number) do
    has_duplicate_keys =
      Enum.group_by(keyword, &elem(&1, 0), &elem(&1, 1))
      |> Enum.any?(fn {_, elements} -> length(elements) > 1 end)

    if has_duplicate_keys do
      raise """
      State #{name} has duplicate attributes
      #{inspect(Enum.map(keyword, &elem(&1, 0)))}
      """
    end

    %EXSM.Macro.State{
      state: %EXSM.State{
        name: name,
        description: Keyword.get(keyword, :description),
        initial?: Keyword.get(keyword, :initial?, false)
      },
      id: make_state_id(name, seq_number),
      on_enter: Keyword.get(keyword, :on_enter),
      on_leave: Keyword.get(keyword, :on_leave)
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
    %State{id: id_from} = Enum.find_value(states_meta, fn
      {^from_value, value} -> value
      _ -> false
    end)
    state_to = Keyword.fetch!(keyword, :to)
    to_value = Keyword.fetch!(keyword, :to_value)
    %State{id: id_to} = Enum.find_value(states_meta, fn
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

  defp parse_transition({:when, _, [left, guard]}, acc) do
    assert_guard_variables(guard)
    parse_transition(left, [{:when, guard} | acc])
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
end
