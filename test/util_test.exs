defmodule EXSM.UtilTest do
  use ExUnit.Case

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
end