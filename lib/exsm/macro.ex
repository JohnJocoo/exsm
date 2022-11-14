defmodule EXSM.Macro do
  @moduledoc false

  alias EXSM.Macro

  defmodule State do
    defstruct [:state, :on_enter, :on_leave]
  end

  def state_from_keyword(name, keyword) do
    has_duplicate_keys =
      Enum.group_by(keyword, &elem(&1, 0), &elem(&1, 1))
      |> Enum.any?(fn {_, elements} -> length(elements) > 1 end)

    if has_duplicate_keys do
      raise """
      State #{name} has duplicate attributes
      #{inspect(Enum.map(keyword, &elem(&1, 0)))}
      """
    end

    %Macro.State{
      state: %EXSM.State{
        name: name,
        description: Keyword.get(keyword, :description),
        initial?: Keyword.get(keyword, :initial?, false)
      },
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
    from = Keyword.fetch!(keyword, :from)
    Elixir.Macro.escape(from)
  end

  def transition_event_from_keyword(keyword) do
    assert_has_keyword(keyword, :event, "transition", "source_state <- event",
      ":stopped <- :play >>> :playing")
    event = Keyword.fetch!(keyword, :event)
    Elixir.Macro.escape(event)
  end

  def transition_when_from_keyword(keyword) do
    if Keyword.has_key?(keyword, :when) do
      when_expression = Keyword.fetch!(keyword, :when)
      Elixir.Macro.escape(when_expression)
    else
      :true
    end
  end

  def transition_action_from_keyword(keyword, state_param, _event_param) do

#    case action.(state, event) do
#      :ok -> {:noreply, to, state}
#      {:noreply, new_state} -> {:noreply, to, new_state}
#      {:reply, reply} -> {:reply, to, reply, state}
#      {:reply, reply, new_state} -> {:reply, to, reply, new_state}
#      {:error, error} -> {:error, error}
#      error -> {:error, error}
#    end
    Elixir.Macro.escape({:noreply, :_ignore, state_param})
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

  defp parse_transition({:>>>, _, [left, to]}, acc) do
    [{:left_to, left} | [{:to, to} | acc]]
  end

  defp parse_transition({:when, _, [left, guard]}, acc) do
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
