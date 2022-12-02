defmodule EXSM.UtilTest do
  use ExUnit.Case

  alias EXSM.Util

  defmodule TestModule do
    use EXSM

    state :one do
      initial true
      describe "State one"
    end

    state "two"

    state {:state, "three"}
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
end