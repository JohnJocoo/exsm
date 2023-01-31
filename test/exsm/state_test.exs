defmodule EXSM.StateTest do
  use ExUnit.Case, async: true

  alias EXSM.State

  test "sub_state_machine not a sub state machine" do
    assert {:error, :not_sub_state_machine} == State.sub_state_machine(%State{name: :test})
  end

  test "sub_state_machine sub state machine not initialized" do
    assert {:error, :state_not_active} == State.sub_state_machine(%State{name: :test, sub_state_machine?: true})
  end

  test "sub_state_machine positive" do
    sub_state_machine = EXSM.StateMachine.new(EXSM.StateTest, [{nil, %State{name: :initial}}], [])
    assert {:ok, sub_state_machine} ==
             State.sub_state_machine(
               %State{name: EXSM.StateTest,
                      sub_state_machine?: true,
                      _sub_state_machine: sub_state_machine
               }
             )
  end
end
