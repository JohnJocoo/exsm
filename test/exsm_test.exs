defmodule EXSMTest do
  use ExUnit.Case
  use ExUnitProperties

  doctest EXSM

  defmodule StatesNone do
    use EXSM
  end

  defmodule StatesOne do
    use EXSM

    state :one
  end

  defmodule StatesThree do
    use EXSM

    state :one
    state :two
    state :three
  end

  defmodule StatesDefaultOne do
    use EXSM

    state :one, do: initial true
    state :two
    state :three
  end

  defmodule StatesDefaultTwo do
    use EXSM

    state :one
    state :two do
      initial true
    end
    state :three
  end

  test "defines __using__" do
    assert macro_exported?(EXSM, :__using__, 1)
  end

  test "defines state" do
    assert macro_exported?(EXSM, :state, 1)
    assert macro_exported?(EXSM, :state, 2)
  end

  test "defines describe" do
    assert macro_exported?(EXSM, :describe, 1)
  end

  test "defines initial" do
    assert macro_exported?(EXSM, :initial, 1)
  end

  test "defines on_enter" do
    assert macro_exported?(EXSM, :on_enter, 1)
    assert macro_exported?(EXSM, :on_enter, 2)
  end

  test "defines on_leave" do
    assert macro_exported?(EXSM, :on_leave, 1)
    assert macro_exported?(EXSM, :on_leave, 2)
  end

  test "defines transitions" do
    assert macro_exported?(EXSM, :transitions, 1)
  end

  test "defines operator <-" do
    assert macro_exported?(EXSM, :<-, 2)
  end

  test "defines action" do
    assert macro_exported?(EXSM, :action, 1)
    assert macro_exported?(EXSM, :action, 2)
  end

  test "states EXSMTest" do
    assert [] == EXSM.states(EXSMTest)
  end

  test "states StatesNone" do
    assert [] == EXSM.states(StatesNone)
  end

  test "states StatesOne" do
    assert [%EXSM.State{name: :one}] == EXSM.states(StatesOne)
  end

  test "states StatesThree" do
    assert 3 == length(EXSM.states(StatesThree))
    assert MapSet.new([
             %EXSM.State{name: :one},
             %EXSM.State{name: :two},
             %EXSM.State{name: :three}
           ]) == MapSet.new(EXSM.states(StatesThree))
  end

  test "new with default initial state StatesDefaultOne" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(StatesDefaultOne)
    assert %EXSM.State{name: :one, initial?: true} == EXSM.StateMachine.current_state(state_machine)
    assert [%EXSM.State{name: :one, initial?: true}] == EXSM.StateMachine.all_current_states(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
  end

  test "new with default initial state StatesDefaultTwo" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(StatesDefaultTwo)
    assert %EXSM.State{name: :two, initial?: true} == EXSM.StateMachine.current_state(state_machine)
    assert [%EXSM.State{name: :two, initial?: true}] == EXSM.StateMachine.all_current_states(state_machine)
    assert :two == EXSM.StateMachine.current_state_id(state_machine)
  end

  test "new with initial state :three StatesDefaultTwo" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(StatesDefaultTwo, initial_states: [:three])
    assert %EXSM.State{name: :three, initial?: false} == EXSM.StateMachine.current_state(state_machine)
    assert [%EXSM.State{name: :three, initial?: false}] == EXSM.StateMachine.all_current_states(state_machine)
    assert :three == EXSM.StateMachine.current_state_id(state_machine)
  end

  test "new with initial state :one StatesThree" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(StatesThree, initial_states: [:one])
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert [%EXSM.State{name: :one}] == EXSM.StateMachine.all_current_states(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
  end

  test "new with initial state :two StatesThree" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(StatesThree, initial_states: [:two])
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(state_machine)
    assert [%EXSM.State{name: :two}] == EXSM.StateMachine.all_current_states(state_machine)
    assert :two == EXSM.StateMachine.current_state_id(state_machine)
  end

  test "new with initial state does not exist StatesThree" do
    check all state <- StreamData.atom(:alphanumeric) do
      assert_raise(ArgumentError,
        ~r/No states .*#{state}.* exist(\n| )for module .*StatesThree/,
        fn -> {:ok, _} = EXSM.new(StatesThree, initial_states: [state]) end)
    end
  end

  test "new without initial state and with no default one StatesOne" do
    check all state <- StreamData.atom(:alphanumeric) do
      assert_raise(ArgumentError,
        ~r/No states .*#{state}.* exist(\n| )for module .*StatesThree/,
        fn -> {:ok, _} = EXSM.new(StatesThree, initial_states: [state]) end)
    end
  end
end
