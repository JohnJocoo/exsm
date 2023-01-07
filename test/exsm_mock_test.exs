defmodule EXSMMockTest do
  use ExUnit.Case, async: false

  import Mock
  import EXSM.Test.Callbacks

  alias EXSM.Test.Callbacks

  defmodule TransitionCallbacks do
    use EXSM.SMAL

    defstruct [history: [], secret: nil]

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

    state :cant_leave do
      on_enter [event: event, user_state: state], do:
        Callbacks.enter_state_noreply(:cant_leave, state, event, TransitionCallbacks.record(state, {:enter, :cant_leave}))

      on_leave [event: event, user_state: state], do:
        Callbacks.leave_state_error(:cant_leave, state, event)
    end

    state :cant_enter do
      on_enter [event: event, user_state: state], do:
        Callbacks.enter_state_error(:cant_enter, state, event)
    end

    transitions do

      :one <- :increment = event >>> :two
        action [user_state: state], do:
          Callbacks.action_noreply(:one_two, state, event, TransitionCallbacks.record(state, {:action, :one_two}))

      :one <- :increment_reply = event >>> :two
        action [user_state: state], do:
          Callbacks.action_reply(:one_two_reply, state, event, {:do_something, state.secret},
            TransitionCallbacks.record(state, {:action, :one_two_reply}))

      :cant_leave <- :fail_leave >>> :one

      :one <- :fail_action = event >>> :two
        action [user_state: state], do: Callbacks.action_error(:one_fail_action, state, event)

      :one <- :fail_enter = event >>> :cant_enter
        action [user_state: state], do:
          Callbacks.action_noreply(:one_cant_enter, state, event,
            TransitionCallbacks.record(state, {:action, :one_cant_enter}))

      :one <- :fail_enter_reply = event >>> :cant_enter
        action [user_state: state], do:
          Callbacks.action_reply(:one_cant_enter_reply, state, event, :reply_data,
            TransitionCallbacks.record(state, {:action, :one_cant_enter_reply}))

      :one <- :stay = event >>> :one
        action [user_state: state], do:
          Callbacks.action_noreply(:one_one, state, event, TransitionCallbacks.record(state, {:action, :one_one}))

      :one <- :stay_reply = event >>> :one
        action [user_state: state], do:
          Callbacks.action_reply(:one_one, state, event, "reply", TransitionCallbacks.record(state, {:action, :one_one}))

      :one <- :stay_error = event >>> :one
        action [user_state: state], do: Callbacks.action_error(:one_one, state, event)

      :cant_leave <- :stay >>> :cant_leave

    end

    def record(%TransitionCallbacks{history: history} = state, value) do
      %TransitionCallbacks{state | history: [value | history]}
    end
  end

  def call_only(calls) do
    Enum.map(calls, fn {_, call, _} -> call end)
  end

  test_with_callbacks_mock "new with on_enter" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    assert [{Callbacks, :enter_state_noreply, [:one, %TransitionCallbacks{}, nil,
              %TransitionCallbacks{history: [{:enter, :one}]}]}] ==
             call_history(Callbacks)
             |> call_only()
  end

  test_with_callbacks_mock "new with error on_enter" do
    assert {:error, :test_enter} == EXSM.new(TransitionCallbacks,
                                      initial_states: [:cant_enter],
                                      user_state: :my_state)

    assert [{Callbacks, :enter_state_error, [:cant_enter, :my_state, nil]}] ==
             call_history(Callbacks)
             |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks order successful transition" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionCallbacks, state_machine, :increment)
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(updated_state_machine)
    assert %TransitionCallbacks{history: [enter: :two, action: :one_two, leave: :one, enter: :one]} ==
             EXSM.StateMachine.user_state(updated_state_machine)

    assert [{Callbacks, :enter_state_noreply,
              [:one, %TransitionCallbacks{history: []}, nil,
                %TransitionCallbacks{history: [{:enter, :one}]}]},
            {Callbacks, :leave_state_noreply,
              [:one, %TransitionCallbacks{history: [{:enter, :one}]}, :increment,
                %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}]},
            {Callbacks, :action_noreply,
              [:one_two, %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}, :increment,
                %TransitionCallbacks{history: [{:action, :one_two}, {:leave, :one}, {:enter, :one}]}]},
            {Callbacks, :enter_state_noreply,
              [:two, %TransitionCallbacks{history: [{:action, :one_two}, {:leave, :one}, {:enter, :one}]}, :increment,
                %TransitionCallbacks{history: [{:enter, :two}, {:action, :one_two}, {:leave, :one}, {:enter, :one}]}]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks order successful transition with reply" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{secret: "secret"})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one], secret: "secret"} == EXSM.StateMachine.user_state(state_machine)

    {:ok, %EXSM.StateMachine{} = updated_state_machine, {:do_something, "secret"}, []} =
      EXSM.process_event(TransitionCallbacks, state_machine, :increment_reply)
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(updated_state_machine)
    assert %TransitionCallbacks{history: [enter: :two, action: :one_two_reply, leave: :one, enter: :one], secret: "secret"} ==
             EXSM.StateMachine.user_state(updated_state_machine)

    assert [{Callbacks, :enter_state_noreply,
             [:one, %TransitionCallbacks{history: [], secret: "secret"}, nil,
               %TransitionCallbacks{history: [{:enter, :one}], secret: "secret"}]},
             {Callbacks, :leave_state_noreply,
               [:one, %TransitionCallbacks{history: [{:enter, :one}], secret: "secret"}, :increment_reply,
                 %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}], secret: "secret"}]},
             {Callbacks, :action_reply,
               [:one_two_reply, %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}], secret: "secret"},
                 :increment_reply, {:do_something, "secret"},
                 %TransitionCallbacks{history: [{:action, :one_two_reply}, {:leave, :one}, {:enter, :one}], secret: "secret"}]},
             {Callbacks, :enter_state_noreply,
               [:two, %TransitionCallbacks{history: [{:action, :one_two_reply}, {:leave, :one}, {:enter, :one}], secret: "secret"},
                 :increment_reply,
                 %TransitionCallbacks{history: [{:enter, :two}, {:action, :one_two_reply}, {:leave, :one}, {:enter, :one}], secret: "secret"}]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks order error on_leave" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:cant_leave],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :cant_leave} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :cant_leave]} == EXSM.StateMachine.user_state(state_machine)

    assert {:error, :test_leave, [state_machine: state_machine]} == EXSM.process_event(TransitionCallbacks, state_machine, :fail_leave)

    assert [{Callbacks, :enter_state_noreply,
             [:cant_leave, %TransitionCallbacks{history: []}, nil,
               %TransitionCallbacks{history: [{:enter, :cant_leave}]}]},
             {Callbacks, :leave_state_error,
               [:cant_leave, %TransitionCallbacks{history: [{:enter, :cant_leave}]}, :fail_leave]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks order error in action" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    assert {:error, :test_action, [state_machine: EXSM.StateMachine.update_user_state(state_machine,
             %TransitionCallbacks{history: [{:enter, :one}, {:leave, :one}, {:enter, :one}]})]} ==
               EXSM.process_event(TransitionCallbacks, state_machine, :fail_action)

    assert [{Callbacks, :enter_state_noreply,
             [:one, %TransitionCallbacks{history: []}, nil,
               %TransitionCallbacks{history: [{:enter, :one}]}]},
             {Callbacks, :leave_state_noreply,
               [:one, %TransitionCallbacks{history: [{:enter, :one}]}, :fail_action,
                 %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}]},
             {Callbacks, :action_error,
               [:one_fail_action, %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}, :fail_action]},
             {Callbacks, :enter_state_noreply,
               [:one, %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}, nil,
                 %TransitionCallbacks{history: [{:enter, :one}, {:leave, :one}, {:enter, :one}]}]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks order error in enter noreply" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    assert {:error, :test_enter, [state_machine: EXSM.StateMachine.update_user_state(state_machine,
             %TransitionCallbacks{history: [{:enter, :one}, {:action, :one_cant_enter}, {:leave, :one}, {:enter, :one}]})]} ==
               EXSM.process_event(TransitionCallbacks, state_machine, :fail_enter)

    assert [{Callbacks, :enter_state_noreply,
             [:one, %TransitionCallbacks{history: []}, nil,
               %TransitionCallbacks{history: [{:enter, :one}]}]},
             {Callbacks, :leave_state_noreply,
               [:one, %TransitionCallbacks{history: [{:enter, :one}]}, :fail_enter,
                 %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}]},
             {Callbacks, :action_noreply,
               [:one_cant_enter, %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}, :fail_enter,
                 %TransitionCallbacks{history: [{:action, :one_cant_enter}, {:leave, :one}, {:enter, :one}]}]},
             {Callbacks, :enter_state_error,
               [:cant_enter, %TransitionCallbacks{history: [{:action, :one_cant_enter}, {:leave, :one}, {:enter, :one}]}, :fail_enter]},
             {Callbacks, :enter_state_noreply,
               [:one, %TransitionCallbacks{history: [{:action, :one_cant_enter}, {:leave, :one}, {:enter, :one}]}, nil,
                 %TransitionCallbacks{history: [{:enter, :one}, {:action, :one_cant_enter}, {:leave, :one}, {:enter, :one}]}]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks order error in enter reply" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    {:error, :test_enter, details} = EXSM.process_event(TransitionCallbacks, state_machine, :fail_enter_reply)
    assert EXSM.StateMachine.update_user_state(state_machine,
             %TransitionCallbacks{history: [{:enter, :one}, {:action, :one_cant_enter_reply}, {:leave, :one}, {:enter, :one}]}
           ) == Keyword.get(details, :state_machine)
    assert :reply_data == Keyword.get(details, :reply)

    assert [{Callbacks, :enter_state_noreply,
             [:one, %TransitionCallbacks{history: []}, nil,
               %TransitionCallbacks{history: [{:enter, :one}]}]},
             {Callbacks, :leave_state_noreply,
               [:one, %TransitionCallbacks{history: [{:enter, :one}]}, :fail_enter_reply,
                 %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}]},
             {Callbacks, :action_reply,
               [:one_cant_enter_reply, %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}, :fail_enter_reply, :reply_data,
                 %TransitionCallbacks{history: [{:action, :one_cant_enter_reply}, {:leave, :one}, {:enter, :one}]}]},
             {Callbacks, :enter_state_error,
               [:cant_enter, %TransitionCallbacks{history: [{:action, :one_cant_enter_reply}, {:leave, :one}, {:enter, :one}]}, :fail_enter_reply]},
             {Callbacks, :enter_state_noreply,
               [:one, %TransitionCallbacks{history: [{:action, :one_cant_enter_reply}, {:leave, :one}, {:enter, :one}]}, nil,
                 %TransitionCallbacks{history: [{:enter, :one}, {:action, :one_cant_enter_reply}, {:leave, :one}, {:enter, :one}]}]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks internal transition noreply" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionCallbacks, state_machine, :stay)
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(updated_state_machine)
    assert %TransitionCallbacks{history: [action: :one_one, enter: :one]} ==
             EXSM.StateMachine.user_state(updated_state_machine)

    assert [{Callbacks, :enter_state_noreply,
             [:one, %TransitionCallbacks{history: []}, nil,
               %TransitionCallbacks{history: [{:enter, :one}]}]},
             {Callbacks, :action_noreply,
               [:one_one, %TransitionCallbacks{history: [{:enter, :one}]}, :stay,
                 %TransitionCallbacks{history: [{:action, :one_one}, {:enter, :one}]}]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks internal transition reply" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    {:ok, %EXSM.StateMachine{} = updated_state_machine, "reply", []} =
      EXSM.process_event(TransitionCallbacks, state_machine, :stay_reply)
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(updated_state_machine)
    assert %TransitionCallbacks{history: [action: :one_one, enter: :one]} ==
             EXSM.StateMachine.user_state(updated_state_machine)

    assert [{Callbacks, :enter_state_noreply,
             [:one, %TransitionCallbacks{history: []}, nil,
               %TransitionCallbacks{history: [{:enter, :one}]}]},
             {Callbacks, :action_reply,
               [:one_one, %TransitionCallbacks{history: [{:enter, :one}]}, :stay_reply, "reply",
                 %TransitionCallbacks{history: [{:action, :one_one}, {:enter, :one}]}]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks internal transition error" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    assert {:error, :test_action, [state_machine: EXSM.StateMachine.update_user_state(state_machine,
             %TransitionCallbacks{history: [enter: :one]})]} ==
               EXSM.process_event(TransitionCallbacks, state_machine, :stay_error)

    assert [{Callbacks, :enter_state_noreply,
             [:one, %TransitionCallbacks{history: []}, nil, %TransitionCallbacks{history: [{:enter, :one}]}]},
             {Callbacks, :action_error,
               [:one_one, %TransitionCallbacks{history: [{:enter, :one}]}, :stay_error]}
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "process_event callbacks internal no leave, no action" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:cant_leave],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :cant_leave} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :cant_leave]} == EXSM.StateMachine.user_state(state_machine)

    assert {:ok, state_machine, []} == EXSM.process_event(TransitionCallbacks, state_machine, :stay)

    assert [{Callbacks, :enter_state_noreply,
             [:cant_leave, %TransitionCallbacks{history: []}, nil, %TransitionCallbacks{history: [{:enter, :cant_leave}]}]},
           ] == call_history(Callbacks)
                |> call_only()
  end

  test_with_callbacks_mock "terminate with on_leave" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    assert :ok == EXSM.terminate(TransitionCallbacks, state_machine)

    assert [{Callbacks, :enter_state_noreply, [:one, %TransitionCallbacks{}, nil,
             %TransitionCallbacks{history: [{:enter, :one}]}]},
             {Callbacks, :leave_state_noreply, [:one, %TransitionCallbacks{history: [enter: :one]}, nil,
               %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}]}
           ] ==
             call_history(Callbacks)
             |> call_only()
  end

  test_with_callbacks_mock "terminate with on_leave error" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:cant_leave],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :cant_leave} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :cant_leave]} == EXSM.StateMachine.user_state(state_machine)

    assert {:error, [{nil, :test_leave}]} == EXSM.terminate(TransitionCallbacks, state_machine)

    assert [{Callbacks, :enter_state_noreply, [:cant_leave, %TransitionCallbacks{}, nil,
             %TransitionCallbacks{history: [{:enter, :cant_leave}]}]},
             {Callbacks, :leave_state_error, [:cant_leave, %TransitionCallbacks{history: [enter: :cant_leave]}, nil]}
           ] ==
             call_history(Callbacks)
             |> call_only()
  end

  test_with_callbacks_mock "terminate callbacks order after successful transition" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionCallbacks,
                                                    initial_states: [:one],
                                                    user_state: %TransitionCallbacks{})
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert %TransitionCallbacks{history: [enter: :one]} == EXSM.StateMachine.user_state(state_machine)

    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionCallbacks, state_machine, :increment)
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(updated_state_machine)
    assert %TransitionCallbacks{history: [enter: :two, action: :one_two, leave: :one, enter: :one]} ==
             EXSM.StateMachine.user_state(updated_state_machine)

    assert :ok == EXSM.terminate(TransitionCallbacks, updated_state_machine)

    assert [{Callbacks, :enter_state_noreply,
             [:one, %TransitionCallbacks{history: []}, nil,
               %TransitionCallbacks{history: [{:enter, :one}]}]},
             {Callbacks, :leave_state_noreply,
               [:one, %TransitionCallbacks{history: [{:enter, :one}]}, :increment,
                 %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}]},
             {Callbacks, :action_noreply,
               [:one_two, %TransitionCallbacks{history: [{:leave, :one}, {:enter, :one}]}, :increment,
                 %TransitionCallbacks{history: [{:action, :one_two}, {:leave, :one}, {:enter, :one}]}]},
             {Callbacks, :enter_state_noreply,
               [:two, %TransitionCallbacks{history: [{:action, :one_two}, {:leave, :one}, {:enter, :one}]}, :increment,
                 %TransitionCallbacks{history: [{:enter, :two}, {:action, :one_two}, {:leave, :one}, {:enter, :one}]}]},
             {Callbacks, :leave_state_noreply,
               [:two, %TransitionCallbacks{history: [{:enter, :two}, {:action, :one_two}, {:leave, :one}, {:enter, :one}]}, nil,
                 %TransitionCallbacks{history: [{:leave, :two}, {:enter, :two}, {:action, :one_two}, {:leave, :one}, {:enter, :one}]}]}
           ] == call_history(Callbacks)
                |> call_only()
  end
end
