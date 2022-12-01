defmodule EXSM.StateMachineTest do
  use ExUnit.Case

  alias EXSM.State
  alias EXSM.StateMachine

  defmodule TestM do

  end

  test "create with one state" do
    state_machine = StateMachine.new(TestM, [%State{name: :empty}], [])
    assert [%State{name: :empty}] == StateMachine.all_current_states(state_machine)
    assert %State{name: :empty} == StateMachine.current_state(state_machine)
    assert nil == StateMachine.user_state(state_machine)
  end

  test "create with one state with region" do
    state_machine = StateMachine.new(TestM, [%State{name: :empty, region: :default}], [])
    assert [%State{name: :empty, region: :default}] == StateMachine.all_current_states(state_machine)
    assert %State{name: :empty, region: :default} == StateMachine.current_state(state_machine, :default)
  end

  test "fail to create with no states" do
    assert_raise FunctionClauseError, fn -> StateMachine.new(TestM, [], []) end
  end

  test "create with two orthogonal states" do
    state_1 = %State{name: :normal, region: :main}
    state_2 = %State{name: :empty, region: :player}
    state_machine = StateMachine.new(TestM, [state_1, state_2], [])
    all_states = StateMachine.all_current_states(state_machine)
    assert state_1 in all_states
    assert state_2 in all_states
    assert state_1 == StateMachine.current_state(state_machine, :main)
    assert state_2 == StateMachine.current_state(state_machine, :player)
    assert nil == StateMachine.user_state(state_machine)
  end

  test "create with three states, but only 2 regions" do
    state_1 = %State{name: :normal, region: :main}
    state_2 = %State{name: :empty, region: :player}
    state_3 = %State{name: :failed, region: :main}
    assert_raise(ArgumentError,
                 ~r/initial states in the same region .?main found .*(normal|failed).*(normal|failed).*TestM.*/,
                 fn -> StateMachine.new(TestM, [state_1, state_2, state_3], []) end)
  end

  test "current_state with non-existing region" do
    state_machine_one_state = StateMachine.new(TestM, [%State{name: :empty}], [])
    assert_raise(ArgumentError,
                 ~r/region .?main does not exist for state machine .*TestM.*/,
                 fn -> StateMachine.current_state(state_machine_one_state, :main) end)
    state_1 = %State{name: :normal, region: :main}
    state_2 = %State{name: :empty, region: :player}
    state_machine_orthogonal = StateMachine.new(TestM, [state_1, state_2], [])
    assert_raise(ArgumentError,
                 ~r/region .?default does not exist for state machine .*TestM.*/,
                 fn -> StateMachine.current_state(state_machine_orthogonal, :default) end)
    assert_raise(ArgumentError,
                 ~r/region .?nil does not exist for state machine .*TestM.*/,
                 fn -> StateMachine.current_state(state_machine_orthogonal, nil) end)
  end

  test "init user state" do
    state_machine = StateMachine.new(TestM, [%State{name: :empty}], [user_state: {:state, "data"}])
    assert {:state, "data"} == StateMachine.user_state(state_machine)
  end

  test "update user state" do
    state_machine = StateMachine.new(TestM, [%State{name: :empty}], [user_state: {:state, "data"}])
    assert {:state, "data"} == StateMachine.user_state(state_machine)
    updated_state_machine = StateMachine.update_user_state(state_machine, {:state, "updated"})
    assert {:state, "updated"} == StateMachine.user_state(updated_state_machine)
  end

  test "update one sm state" do
    state_machine = StateMachine.new(TestM, [%State{name: :empty}], [])
    assert %State{name: :empty} == StateMachine.current_state(state_machine)
    updated_state_machine = StateMachine.update_current_state(state_machine, %State{name: :full})
    assert %State{name: :full} == StateMachine.current_state(updated_state_machine)
  end

  test "update one sm state with region" do
    initial_state = %State{name: :empty, region: :default}
    state_machine = StateMachine.new(TestM, [initial_state], [])
    assert initial_state == StateMachine.current_state(state_machine, :default)
    new_state = %State{name: :full, region: :default}
    updated_state_machine = StateMachine.update_current_state(state_machine, new_state, :default)
    assert new_state == StateMachine.current_state(updated_state_machine, :default)
  end

  test "update sm two states with regions" do

  end

  test "update sm states with non-existing regions" do

  end
end