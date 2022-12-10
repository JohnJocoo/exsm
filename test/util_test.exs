defmodule EXSM.UtilTest do
  use ExUnit.Case
  use ExUnitProperties

  alias EXSM.Util
  alias EXSM.Test.Callbacks

  defmodule TestModule do
    use EXSM

    state :one do
      initial true
      describe "State one"
    end

    state "two"

    state {:state, "three"}

    state :on_enter_0 do
      on_enter &Callbacks.function_0/0
    end

    state :on_enter_2 do
      on_enter &Callbacks.function_2/2
    end

    state :on_enter_do do
      on_enter do: Callbacks.function_1({TestModule, :on_enter_do})
    end

    state :on_enter_do_state do
      on_enter [user_state: state], do: Callbacks.function_2({TestModule, :on_enter_do_state}, state)
    end

    state :on_enter_do_event do
      on_enter [event: event], do: Callbacks.function_2({TestModule, :on_enter_do_event}, event)
    end

    state :on_enter_do_state_event do
      on_enter user_state: user_state, event: my_event do
        Callbacks.function_3({TestModule, :on_enter_do_state_event}, user_state, my_event)
      end
    end

    state :on_leave_0 do
      on_leave &Callbacks.function_0/0
    end

    state :on_leave_2 do
      on_leave &Callbacks.function_2/2
    end

    state :on_leave_do do
      on_leave do
        Callbacks.function_1({TestModule, :on_leave_do})
      end
    end

    state :on_leave_do_state do
      on_leave user_state: my_state do
        Callbacks.function_2({TestModule, :on_leave_do_state}, my_state)
      end
    end

    state :on_leave_do_event do
      on_leave event: new_event do
        Callbacks.function_2({TestModule, :on_leave_do_event}, new_event)
      end
    end

    state :on_leave_do_state_event do
      on_leave [user_state: st, event: ev], do: Callbacks.function_3({TestModule, :on_leave_do_st_ev}, st, ev)
    end
  end

  defmodule TransitionTestModule do
    use EXSM

    state :one
    state :two
    state :three
    state %{state: "one"}
    state %{state: "two"}
    state :initial
    state :ok
    state :error
    state :stopped
    state :playing
    state :paused
    state :open
    state :closed
    state :locked

    transitions do
      :one <- :increment >>> :two
      :two <- :increment >>> :three
      :two <- :decrement >>> :one
      :one <- {:add, 2} >>> :three

      %{state: "one"} <- event >>> %{state: "two"} when is_binary(event) and event in ["increment", "double"]

      :initial <- :go_to_ok >>> :ok
      :initial <- _ >>> :error

      :stopped <- :play >>> :playing
        action &Callbacks.function_0/0
      :playing <- :stop >>> :stopped
        action &Callbacks.function_2/2
      :playing <- :pause >>> :paused
        action do: Callbacks.function_1(:playing_pause)
      :paused <- :pause >>> :playing
        action do
          Callbacks.function_1(:paused_pause)
        end
      :paused <- :stop >>> :stopped
        action user_state: state do
          Callbacks.function_1(state)
        end
      :paused <- :play >>> :playing
        action [user_state: state], do: Callbacks.function_1(state)

      :open <- :close = event >>> :closed
        action do: Callbacks.function_1(event)
      :closed <- :open = open_event >>> :open
        action do
          Callbacks.function_1(open_event)
        end
      :closed <- event >>> :locked when event in [:lock, :secure]
        action user_state: state do
          Callbacks.function_2(state, event)
        end
      :locked <- {:unlock, code} >>> :closed when code == "1234"
        action [user_state: state], do: Callbacks.function_2(state, code)
    end
  end

  test "assert_state_function 0 arity" do
    assert :ok == Util.assert_state_function(fn -> :ok end, "test")
  end

  test "assert_state_function 2 arity" do
    assert :ok == Util.assert_state_function(fn state, event -> {state, event} end, "test")
  end

  test "assert_state_function 1 arity fail" do
    assert_raise(RuntimeError,
                 fn -> Util.assert_state_function(fn _ -> :ok end, "test") end)
  end

  test "assert_state_function 3 arity fail" do
    assert_raise(RuntimeError,
                 fn -> Util.assert_state_function(fn _, _, _ -> :ok end, "test") end)
  end

  test "assert_only_allowed_keywords 1 allowed" do
    check all key <- StreamData.atom(:alphanumeric),
              value <- StreamData.term() do
      assert :ok == Util.assert_only_allowed_keywords([{key, value}], [key], "test")
    end
  end

  test "assert_only_allowed_keywords 2 allowed" do
    check all key1 <- StreamData.atom(:alphanumeric),
              key2 <- StreamData.atom(:alphanumeric),
              value <- StreamData.term() do
      assert :ok == Util.assert_only_allowed_keywords([{key1, value}], [key1, key2], "test")
    end
    check all key1 <- StreamData.atom(:alphanumeric),
              key2 <- StreamData.atom(:alphanumeric),
              value <- StreamData.term() do
      assert :ok == Util.assert_only_allowed_keywords([{key1, value}, {key2, value}], [key1, key2], "test")
    end
  end

  test "assert_only_allowed_keywords 0 allowed" do
    check all key <- StreamData.atom(:alphanumeric),
              value <- StreamData.term() do
      assert_raise(RuntimeError,
        fn -> Util.assert_only_allowed_keywords([{key, value}], [], "test") end)
    end
  end

  test "assert_only_allowed_keywords not in allowed" do
    check all key1 <- StreamData.atom(:alphanumeric),
              value <- StreamData.term() do
      assert_raise(RuntimeError,
        fn -> Util.assert_only_allowed_keywords([{key1, value}], [:does_not_exist], "test") end)
    end
  end

  test "function_to_arity_2 arity 2" do
    ast = quote do
      fn _, _ -> :ok end
    end
    assert ast == Util.function_to_arity_2(fn _, _ -> :ok end, ast)
  end

  test "function_to_arity_2 arity 0" do
    ast = quote do
      fn -> :run_success end
    end
    result_ast = Util.function_to_arity_2(fn -> :run_success end, ast)
    assert result_ast != ast
    {function, _} = Code.eval_quoted(result_ast)
    assert 2 == Keyword.fetch!(:erlang.fun_info(function), :arity)
    assert :run_success == function.(:state, :event)
  end

  test "parent_module EXSM.Util" do
    assert EXSM == Util.parent_module(EXSM.Util)
    assert EXSM == Util.parent_module(Util)
  end

  test "parent_module EXSM" do
    assert Elixir == Util.parent_module(EXSM)
  end
  
  test "state_full_by_name :one" do
    expected = %EXSM.State{name: :one, description: "State one", initial?: true}
    assert {:ok, expected, :one} == Util.state_full_by_name(TestModule, :one)
  end

  test "state_full_by_name state does not exist" do
    assert {:error, :not_found} == Util.state_full_by_name(TestModule, :not_exists)
  end

  test "state_full_by_name two" do
    expected = %EXSM.State{name: "two"}
    assert {:ok, expected, :two} == Util.state_full_by_name(TestModule, "two")
  end

  test "state_full_by_name three" do
    expected = %EXSM.State{name: {:state, "three"}}
    {:ok, ^expected, state_id} = Util.state_full_by_name(TestModule, {:state, "three"})
    assert is_atom(state_id)
  end

  test "state_id_by_name :one" do
    assert {:ok, :one} == Util.state_id_by_name(TestModule, :one)
  end

  test "state_id_by_name state does not exist" do
    assert {:error, :not_found} == Util.state_id_by_name(TestModule, :not_exists)
  end

  test "state_id_by_name two" do
    assert {:ok, :two} == Util.state_id_by_name(TestModule, "two")
  end

  test "state_id_by_name three" do
    {:ok, state_id} = Util.state_id_by_name(TestModule, {:state, "three"})
    assert is_atom(state_id)
  end

  test "state_by_id :one" do
    expected = %EXSM.State{name: :one, description: "State one", initial?: true}
    assert expected == Util.state_by_id(TestModule, :one)
  end

  test "state_by_id three" do
    {:ok, state_id} = Util.state_id_by_name(TestModule, {:state, "three"})
    assert is_atom(state_id)
    expected = %EXSM.State{name: {:state, "three"}}
    assert expected == Util.state_by_id(TestModule, state_id)
  end

  test "on_enter_by_id :on_enter_0" do
    function = Util.on_enter_by_id(TestModule, :on_enter_0)
    assert {Callbacks, :function_0} = function.(:state, :event)
  end

  test "on_enter_by_id :on_enter_2" do
    function = Util.on_enter_by_id(TestModule, :on_enter_2)
    assert {Callbacks, :function_2, :state, :event} = function.(:state, :event)
  end

  test "on_enter_by_id :on_enter_do" do
    function = Util.on_enter_by_id(TestModule, :on_enter_do)
    assert {Callbacks, :function_1, {TestModule, :on_enter_do}} = function.(:state, :event)
  end

  test "on_enter_by_id :on_enter_do_state" do
    function = Util.on_enter_by_id(TestModule, :on_enter_do_state)
    assert {Callbacks, :function_2, {TestModule, :on_enter_do_state}, :state} = function.(:state, :event)
  end

  test "on_enter_by_id :on_enter_do_event" do
    function = Util.on_enter_by_id(TestModule, :on_enter_do_event)
    assert {Callbacks, :function_2, {TestModule, :on_enter_do_event}, :event} = function.(:state, :event)
  end

  test "on_enter_by_id :on_enter_do_state_event" do
    function = Util.on_enter_by_id(TestModule, :on_enter_do_state_event)
    assert {Callbacks, :function_3, {TestModule, :on_enter_do_state_event}, :state, :event} = function.(:state, :event)
  end

  test "on_enter_by_id :one" do
    assert nil == Util.on_enter_by_id(TestModule, :one)
  end

  test "on_leave_by_id :on_leave_0" do
    function = Util.on_leave_by_id(TestModule, :on_leave_0)
    assert {Callbacks, :function_0} = function.(:state, :event)
  end

  test "on_leave_by_id :on_leave_2" do
    function = Util.on_leave_by_id(TestModule, :on_leave_2)
    assert {Callbacks, :function_2, :state, :event} = function.(:state, :event)
  end

  test "on_leave_by_id :on_leave_do" do
    function = Util.on_leave_by_id(TestModule, :on_leave_do)
    assert {Callbacks, :function_1, {TestModule, :on_leave_do}} = function.(:state, :event)
  end

  test "on_leave_by_id :on_leave_do_state" do
    function = Util.on_leave_by_id(TestModule, :on_leave_do_state)
    assert {Callbacks, :function_2, {TestModule, :on_leave_do_state}, :state} = function.(:state, :event)
  end

  test "on_leave_by_id :on_leave_do_event" do
    function = Util.on_leave_by_id(TestModule, :on_leave_do_event)
    assert {Callbacks, :function_2, {TestModule, :on_leave_do_event}, :event} = function.(:state, :event)
  end

  test "on_leave_by_id :on_leave_do_state_event" do
    function = Util.on_leave_by_id(TestModule, :on_leave_do_state_event)
    assert {Callbacks, :function_3, {TestModule, :on_leave_do_st_ev}, :state, :event} = function.(:state, :event)
  end

  test "on_leave_by_id :one" do
    assert nil == Util.on_leave_by_id(TestModule, :one)
  end

  test "transition_info :non_existing_state <- :increment" do
    assert {:no_transition, :reply} ==
             Util.transition_info(TransitionTestModule, :non_existing_state, :increment, nil)
  end

  test "transition_info :one <- :non_existing_event" do
    assert {:no_transition, :reply} ==
             Util.transition_info(TransitionTestModule, :one, :non_existing_event, nil)
  end

  test "transition_info :one <- :increment >>> :two" do
    assert {:transition, {{:one, :one}, {:two, :two}, nil}} ==
             Util.transition_info(TransitionTestModule, :one, :increment, nil)
  end

  test "transition_info :two <- :increment >>> :three" do
    assert {:transition, {{:two, :two}, {:three, :three}, nil}} ==
             Util.transition_info(TransitionTestModule, :two, :increment, nil)
  end

  test "transition_info :two <- :decrement >>> :one" do
    assert {:transition, {{:two, :two}, {:one, :one}, nil}} ==
             Util.transition_info(TransitionTestModule, :two, :decrement, nil)
  end

  test "transition_info :one <- {:add, 2} >>> :three" do
    assert {:transition, {{:one, :one}, {:three, :three}, nil}} ==
             Util.transition_info(TransitionTestModule, :one, {:add, 2}, nil)
  end

  test "transition_info %{state: 'one'} <- 'increment' >>> %{state: 'two'}" do
    {:ok, from_id} = Util.state_id_by_name(TransitionTestModule, %{state: "one"})
    {:ok, to_id} = Util.state_id_by_name(TransitionTestModule, %{state: "two"})
    assert {:transition, {{%{state: "one"}, from_id}, {%{state: "two"}, to_id}, nil}} ==
             Util.transition_info(TransitionTestModule, %{state: "one"}, "increment", nil)

  end

  test "transition_info %{state: 'one'} <- 'double' >>> %{state: 'two'}" do
    {:ok, from_id} = Util.state_id_by_name(TransitionTestModule, %{state: "one"})
    {:ok, to_id} = Util.state_id_by_name(TransitionTestModule, %{state: "two"})
    assert {:transition, {{%{state: "one"}, from_id}, {%{state: "two"}, to_id}, nil}} ==
             Util.transition_info(TransitionTestModule, %{state: "one"}, "double", nil)

  end

  test "transition_info %{state: 'one'} <- 'triple' >>> %{state: 'two'}" do
    assert {:no_transition, :reply} ==
             Util.transition_info(TransitionTestModule, %{state: "one"}, "triple", nil)

  end

  test "transition_info :initial <- :go_to_ok >>> :ok" do
    assert {:transition, {{:initial, :initial}, {:ok, :ok}, nil}} ==
             Util.transition_info(TransitionTestModule, :initial, :go_to_ok, nil)
  end

  test "transition_info :initial <- _ >>> :error" do
    check all event <- StreamData.atom(:alphanumeric) do
      assert {:transition, {{:initial, :initial}, {:error, :error}, nil}} ==
               Util.transition_info(TransitionTestModule, :initial, event, nil)
    end
  end

  test "transition_info :stopped <- :play >>> :playing" do
    {:transition, {{:stopped, :stopped}, {:playing, :playing}, function}} =
             Util.transition_info(TransitionTestModule, :stopped, :play, nil)
    assert {Callbacks, :function_0} == function.()
  end

  test "transition_info :playing <- :stop >>> :stopped" do
    {:transition, {{:playing, :playing}, {:stopped, :stopped}, function}} =
      Util.transition_info(TransitionTestModule, :playing, :stop, {:state, 1})
    assert {Callbacks, :function_2, {:state, 1}, :stop} == function.()
  end

  test "transition_info :playing <- :pause >>> :paused" do
    {:transition, {{:playing, :playing}, {:paused, :paused}, function}} =
      Util.transition_info(TransitionTestModule, :playing, :pause, nil)
    assert {Callbacks, :function_1, :playing_pause} == function.()
  end

  test "transition_info :paused <- :pause >>> :playing" do
    {:transition, {{:paused, :paused}, {:playing, :playing}, function}} =
      Util.transition_info(TransitionTestModule, :paused, :pause, nil)
    assert {Callbacks, :function_1, :paused_pause} == function.()
  end

  test "transition_info :paused <- :stop >>> :stopped" do
    {:transition, {{:paused, :paused}, {:stopped, :stopped}, function}} =
      Util.transition_info(TransitionTestModule, :paused, :stop, {:state, 2})
    assert {Callbacks, :function_1, {:state, 2}} == function.()
  end

  test "transition_info :paused <- :play >>> :playing" do
    {:transition, {{:paused, :paused}, {:playing, :playing}, function}} =
      Util.transition_info(TransitionTestModule, :paused, :play, {:state, 3})
    assert {Callbacks, :function_1, {:state, 3}} == function.()
  end

  test "transition_info :open <- :close = event >>> :closed" do
    {:transition, {{:open, :open}, {:closed, :closed}, function}} =
      Util.transition_info(TransitionTestModule, :open, :close, nil)
    assert {Callbacks, :function_1, :close} == function.()
  end
end