defmodule EXSM.SubMachineTest do
  use ExUnit.Case, async: true

  alias EXSM.State
  alias EXSM.StateMachine

  defmodule SimpleSubMachine do
    use EXSM.SMAL
    use EXSM.Functions, [:new, :terminate]

    state :one, do: initial true
    state :two
    state :three, do: terminal true

    transitions do
      :one <- :increment >>> :two
      :two <- :increment >>> :three
    end
  end

  defmodule SimpleMachine do
    use EXSM.SMAL, default_user_state: %{token: "ab12"}

    state :initial do
      initial true
    end

    state :final do
      terminal true
    end

    state SimpleSubMachine do
      sub_machine true
      init_opts [user_state: %{data: "hello"}]
    end

    state :sub_machine_custom do
      sub_machine true
      module SimpleSubMachine
      new [user_state: %{token: token}, event: event] do
        SimpleSubMachine.new(initial_states: [:three], user_state: %{token: token, event: event})
      end
      terminate [state_machine: state_machine] do
        SimpleSubMachine.terminate(state_machine)
      end
    end

    transitions do
      :initial <- :to_sub_machine >>> SimpleSubMachine
      :initial <- :to_custom_sub_machine >>> :sub_machine_custom
      SimpleSubMachine <- :finish >>> :final
      :sub_machine_custom <- :increment >>> :final
    end
  end

  test "sub machine as initial state" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(SimpleMachine, initial_states: [SimpleSubMachine])
    %State{
      name: SimpleSubMachine,
      sub_state_machine?: true
    } = current_state = StateMachine.current_state(state_machine)
    {:ok, %StateMachine{module: SimpleSubMachine} = sub_machine} = State.sub_state_machine(current_state)
    assert %State{name: :one, initial?: true} == StateMachine.current_state(sub_machine)
    assert %{data: "hello"} == StateMachine.user_state(sub_machine)
  end

  test "normal state move to sub machine state" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(SimpleMachine)
    assert %State{name: :initial, initial?: true} == StateMachine.current_state(state_machine)
    {:ok, %StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(SimpleMachine, state_machine, :to_sub_machine)
    %State{
      name: SimpleSubMachine,
      sub_state_machine?: true
    } = current_state = StateMachine.current_state(updated_state_machine)
    {:ok, %StateMachine{module: SimpleSubMachine} = sub_machine} = State.sub_state_machine(current_state)
    assert %State{name: :one, initial?: true} == StateMachine.current_state(sub_machine)
    assert %{data: "hello"} == StateMachine.user_state(sub_machine)
  end

  test "leave sub machine state" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(SimpleMachine, initial_states: [:sub_machine_custom])
    %State{
      name: :sub_machine_custom,
      sub_state_machine?: true
    } = StateMachine.current_state(state_machine)
    {:ok, %StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(SimpleMachine, state_machine, :increment)
    assert %State{name: :final, terminal?: true} == StateMachine.current_state(updated_state_machine)
    assert :ok == EXSM.terminate(SimpleMachine, updated_state_machine)
  end

  test "terminating with sub machine state" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(SimpleMachine, initial_states: [SimpleSubMachine])
    %State{
      name: SimpleSubMachine,
      sub_state_machine?: true
    } = StateMachine.current_state(state_machine)
    assert :ok == EXSM.terminate(SimpleMachine, state_machine)
  end

  test "test events processing order with sub machine" do

  end
end
