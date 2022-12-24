defmodule EXSMMockTest do
  use ExUnit.Case, async: false

  import Mock
  import EXSM.Test.Callbacks

  alias EXSM.Test.Callbacks

  defmodule TransitionCallbacks do
    use EXSM

    defstruct [history: []]

    state :one do
      on_enter [event: event, user_state: state], do:
        Callbacks.enter_state_noreply(:one, state, event, TransitionCallbacks.record(state, {:enter, :one}))

      on_leave [event: event, user_state: state], do:
        Callbacks.leave_state_noreply(:one, state, event, TransitionCallbacks.record(state, {:leave, :one}))
    end

    state :two do
      on_enter [event: event, user_state: state], do:
        Callbacks.enter_state_noreply(:two, state, event, TransitionCallbacks.record(state, {:enter, :two}))

      on_leave [event: event, user_state: state], do:
        Callbacks.leave_state_noreply(:two, state, event, TransitionCallbacks.record(state, {:leave, :two}))
    end

    transitions do

      :one <- event >>> :two
      action [user_state: state], do:
        Callbacks.action_noreply(:one_two, state, event, TransitionCallbacks.record(state, {:action, :one_two}))

    end

    def record(%TransitionCallbacks{history: history} = state, value) do
      %TransitionCallbacks{state | history: [value | history]}
    end
  end

  test_with_callbacks_mock "process_event callbacks order successful transition" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)
    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionCallbacks, state_machine, :some_event)
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(updated_state_machine)
    assert %TransitionCallbacks{history: [enter: :two, action: :one_two, leave: :one, enter: :one]} ==
             EXSM.StateMachine.user_state(updated_state_machine)
  end
end
