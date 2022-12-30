defmodule EXSM.StateMachineTest do
  use ExUnit.Case

  alias EXSM.State
  alias EXSM.StateMachine

  defmodule TestM do

  end

  test "create with one state" do
    state_machine = StateMachine.new(TestM, [{:empty, %State{name: :empty}}], [])
    assert [%State{name: :empty}] == StateMachine.all_current_states(state_machine)
    assert %State{name: :empty} == StateMachine.current_state(state_machine)
    assert :empty == StateMachine.current_state_id(state_machine)
    assert nil == StateMachine.user_state(state_machine)
  end

  test "fail to create with no states" do
    assert_raise FunctionClauseError, fn -> StateMachine.new(TestM, [], []) end
  end

  test "init user state" do
    state_machine = StateMachine.new(TestM, [{:empty, %State{name: :empty}}], [user_state: {:state, "data"}])
    assert {:state, "data"} == StateMachine.user_state(state_machine)
  end

  test "update user state" do
    state_machine = StateMachine.new(TestM, [{:empty, %State{name: :empty}}], [user_state: {:state, "data"}])
    assert {:state, "data"} == StateMachine.user_state(state_machine)
    updated_state_machine = StateMachine.update_user_state(state_machine, {:state, "updated"})
    assert {:state, "updated"} == StateMachine.user_state(updated_state_machine)
  end

  test "update one sm state" do
    state_machine = StateMachine.new(TestM, [{:empty, %State{name: :empty}}], [])
    assert %State{name: :empty} == StateMachine.current_state(state_machine)
    assert :empty == StateMachine.current_state_id(state_machine)
    updated_state_machine = StateMachine.update_current_state(state_machine, {:full, %State{name: :full}})
    assert %State{name: :full} == StateMachine.current_state(updated_state_machine)
    assert :full == StateMachine.current_state_id(updated_state_machine)
  end
end