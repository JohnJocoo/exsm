defmodule EXSMTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest EXSM

  defmodule StatesNone do
    use EXSM.SMAL
  end

  defmodule StatesOne do
    use EXSM.SMAL

    state :one
  end

  defmodule StatesThree do
    use EXSM.SMAL

    state :one
    state :two
    state :three
  end

  defmodule StatesDefaultOne do
    use EXSM.SMAL

    state :one, do: initial true
    state :two
    state :three
  end

  defmodule StatesDefaultTwo do
    use EXSM.SMAL

    state :one
    state :two do
      initial true
    end
    state :three
  end

  defmodule TransitionSimpleOne do
    use EXSM.SMAL

    state :one, do: initial true
    state :two

    transitions do
      :one <- :increment >>> :two
    end
  end

  defmodule TransitionSimpleOneReply do
    use EXSM.SMAL, no_transition: :reply

    state :one, do: initial true
    state :two

    transitions do
      :one <- :increment >>> :two
    end
  end

  defmodule TransitionSimpleOneIgnore do
    use EXSM.SMAL, no_transition: :ignore

    state :one, do: initial true
    state :two

    transitions do
      :one <- :increment >>> :two
    end
  end

  defmodule TransitionSimpleOneError do
    use EXSM.SMAL, no_transition: :error

    state :one, do: initial true
    state :two

    transitions do
      :one <- :increment >>> :two
    end
  end

  defmodule TransitionSimpleOneNoFunctionMatch do
    use EXSM.SMAL, no_transition: :no_function_match

    state :one, do: initial true
    state :two

    transitions do
      :one <- :increment >>> :two
    end
  end

  defmodule TransitionSimpleFour do
    use EXSM.SMAL

    state :one, do: initial true
    state :two
    state :three

    transitions do
      :one <- :increment >>> :two
      :two <- :increment >>> :three
      :three <- :decrement >>> :two
      :two <- :decrement >>> :one
    end
  end

  defmodule TransitionMatchOrder do
    use EXSM.SMAL

    state :one
    state :two
    state :three
    state :dunno

    transitions do
      :one <- _event >>> :dunno
      :one <- :increment >>> :two
      :two <- :increment >>> :three
      :two <- _event >>> :dunno
      :two <- {:substruct, _value} >>> :dunno
      :two <- {:substruct, 1} >>> :one
    end
  end

  defmodule DefaultUserStateValue do
    use EXSM.SMAL, default_user_state: {:user_state, "data"}

    state :one, do: initial true
  end

  defmodule DefaultUserStateFunction do
    use EXSM.SMAL, default_user_state: fn -> {:user_state, "function"} end

    state :one, do: initial true
  end

  defmodule TerminalState do
    use EXSM.SMAL

    state :one, do: initial true
    state :two, do: terminal true

    transitions do
      :one <- :event >>> :two
      :two <- :back >>> :one
    end
  end

  defmodule TerminalStateReply do
    use EXSM.SMAL, no_transition: :reply

    state :one, do: terminal true
    state :two

    transitions do
      :one <- :event >>> :two
    end
  end

  defmodule TerminalStateIgnore do
    use EXSM.SMAL, no_transition: :ignore

    state :one, do: terminal true
    state :two

    transitions do
      :one <- :event >>> :two
    end
  end

  defmodule TerminalStateError do
    use EXSM.SMAL, no_transition: :error

    state :one, do: terminal true
    state :two

    transitions do
      :one <- :event >>> :two
    end
  end

  defmodule TerminalStateNoFunctionMatch do
    use EXSM.SMAL, no_transition: :no_function_match

    state :one, do: terminal true
    state :two

    transitions do
      :one <- :event >>> :two
    end
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

  test "states TerminalState" do
    assert MapSet.new([
             %EXSM.State{name: :one, initial?: true},
             %EXSM.State{name: :two, terminal?: true},
           ]) == MapSet.new(EXSM.states(TerminalState))
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

  test "new with user_state" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(StatesDefaultOne, user_state: {:state, "initial"})
    assert {:state, "initial"} == EXSM.StateMachine.user_state(state_machine)
  end

  test "new with user_state random" do
    check all state <- StreamData.atom(:alphanumeric) do
      {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(StatesDefaultOne, user_state: state)
      assert state == EXSM.StateMachine.user_state(state_machine)
    end
  end

  test "process_event simple one :one <- :increment >>> :two" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionSimpleOne)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
    assert false == EXSM.StateMachine.terminal?(state_machine)

    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionSimpleOne, state_machine, :increment)
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(updated_state_machine)
    assert :two == EXSM.StateMachine.current_state_id(updated_state_machine)
    assert false == EXSM.StateMachine.terminal?(updated_state_machine)
  end

  test "process_event simple one reply (default) no transition" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionSimpleOne)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
    assert :reply == state_machine.default_transition_policy

    check all event <- StreamData.atom(:alphanumeric) do
      {:ok, %EXSM.StateMachine{} = updated_state_machine, :no_transition, []} =
        EXSM.process_event(TransitionSimpleOne, state_machine, event)
      assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(updated_state_machine)
      assert :one == EXSM.StateMachine.current_state_id(updated_state_machine)
    end
  end

  test "process_event simple one reply no transition" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionSimpleOneReply)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
    assert :reply == state_machine.default_transition_policy

    {:ok, %EXSM.StateMachine{} = updated_state_machine, :no_transition, []} =
      EXSM.process_event(TransitionSimpleOneReply, state_machine, :decrement)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(updated_state_machine)
    assert :one == EXSM.StateMachine.current_state_id(updated_state_machine)
  end

  test "process_event simple one ignore no transition" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionSimpleOneIgnore)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
    assert :ignore == state_machine.default_transition_policy

    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionSimpleOneIgnore, state_machine, :decrement)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(updated_state_machine)
    assert :one == EXSM.StateMachine.current_state_id(updated_state_machine)
  end

  test "process_event simple one error no transition" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionSimpleOneError)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
    assert :error == state_machine.default_transition_policy

    {:error, :no_transition, [state_machine: updated_state_machine]} =
      EXSM.process_event(TransitionSimpleOneError, state_machine, :decrement)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(updated_state_machine)
    assert :one == EXSM.StateMachine.current_state_id(updated_state_machine)
  end

  test "process_event simple one no_function_match no transition" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionSimpleOneNoFunctionMatch)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
    assert :no_function_match == state_machine.default_transition_policy

    assert_raise(FunctionClauseError,
      fn ->
        EXSM.process_event(TransitionSimpleOneNoFunctionMatch, state_machine, :decrement)
      end
    )
  end

  test "process_event simple four :one -> :two -> :three -> :two -> :one" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionSimpleFour)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)

    {:ok, %EXSM.StateMachine{} = state_machine, []} =
      EXSM.process_event(TransitionSimpleFour, state_machine, :increment)
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(state_machine)
    assert :two == EXSM.StateMachine.current_state_id(state_machine)

    {:ok, %EXSM.StateMachine{} = state_machine, []} =
      EXSM.process_event(TransitionSimpleFour, state_machine, :increment)
    assert %EXSM.State{name: :three} == EXSM.StateMachine.current_state(state_machine)
    assert :three == EXSM.StateMachine.current_state_id(state_machine)

    {:ok, %EXSM.StateMachine{} = state_machine, []} =
      EXSM.process_event(TransitionSimpleFour, state_machine, :decrement)
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(state_machine)
    assert :two == EXSM.StateMachine.current_state_id(state_machine)

    {:ok, %EXSM.StateMachine{} = state_machine, []} =
      EXSM.process_event(TransitionSimpleFour, state_machine, :decrement)
    assert %EXSM.State{initial?: true, name: :one} == EXSM.StateMachine.current_state(state_machine)
    assert :one == EXSM.StateMachine.current_state_id(state_machine)
  end

  test "process_event match order generic event clause hides everything below" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionMatchOrder, initial_states: [:one])
    assert %EXSM.State{name: :one} == EXSM.StateMachine.current_state(state_machine)
    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionMatchOrder, state_machine, :increment)
    assert %EXSM.State{name: :dunno} == EXSM.StateMachine.current_state(updated_state_machine)

    check all event <- StreamData.term() do
      {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
        EXSM.process_event(TransitionMatchOrder, state_machine, event)
      assert %EXSM.State{name: :dunno} == EXSM.StateMachine.current_state(updated_state_machine)
    end
  end

  test "process_event match order generic event clause at bottom" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionMatchOrder, initial_states: [:two])
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(state_machine)
    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionMatchOrder, state_machine, :increment)
    assert %EXSM.State{name: :three} == EXSM.StateMachine.current_state(updated_state_machine)

    check all event <- StreamData.term() do
      {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
        EXSM.process_event(TransitionMatchOrder, state_machine, event)
      assert %EXSM.State{name: :dunno} == EXSM.StateMachine.current_state(updated_state_machine)
    end
  end

  test "process_event match order generic event clause hides everything below, tuple" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TransitionMatchOrder, initial_states: [:two])
    assert %EXSM.State{name: :two} == EXSM.StateMachine.current_state(state_machine)
    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TransitionMatchOrder, state_machine, {:substruct, 1})
    assert %EXSM.State{name: :dunno} == EXSM.StateMachine.current_state(updated_state_machine)

    check all event <- StreamData.term() do
      {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
        EXSM.process_event(TransitionMatchOrder, state_machine, {:substruct, event})
      assert %EXSM.State{name: :dunno} == EXSM.StateMachine.current_state(updated_state_machine)
    end
  end

  test "terminate StatesDefaultOne" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(StatesDefaultOne)
    assert [%EXSM.State{name: :one, initial?: true}] == EXSM.StateMachine.all_current_states(state_machine)
    assert :ok == EXSM.terminate(StatesDefaultOne, state_machine)
  end

  test "new DefaultUserStateValue default state" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(DefaultUserStateValue)
    assert {:user_state, "data"} == EXSM.StateMachine.user_state(state_machine)
  end

  test "new DefaultUserStateFunction default state" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(DefaultUserStateFunction)
    assert {:user_state, "function"} == EXSM.StateMachine.user_state(state_machine)
  end

  test "new DefaultUserStateValue override user state in opts" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(DefaultUserStateValue, user_state: :my_state)
    assert :my_state == EXSM.StateMachine.user_state(state_machine)
  end

  test "terminal state makes state machine terminal" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TerminalState)
    assert %EXSM.State{name: :one, initial?: true} ==
             EXSM.StateMachine.current_state(state_machine)
    assert false == EXSM.StateMachine.terminal?(state_machine)
    {:ok, %EXSM.StateMachine{} = updated_state_machine, []} =
      EXSM.process_event(TerminalState, state_machine, :event)

    assert %EXSM.State{name: :two, terminal?: true} ==
             EXSM.StateMachine.current_state(updated_state_machine)
    assert true == EXSM.StateMachine.terminal?(updated_state_machine)
    assert {:ok, updated_state_machine, :no_transition, []} ==
      EXSM.process_event(TerminalState, updated_state_machine, :back)
  end

  test "terminal state machine reply" do
    {:ok, %EXSM.StateMachine{} = state_machine} =
         EXSM.new(TerminalStateReply, initial_states: [:one])
    assert %EXSM.State{name: :one, terminal?: true} ==
             EXSM.StateMachine.current_state(state_machine)
    assert true == EXSM.StateMachine.terminal?(state_machine)
    assert {:ok, state_machine, :no_transition, []} ==
      EXSM.process_event(TerminalStateReply, state_machine, :event)
  end

  test "terminal state machine ignore" do
    {:ok, %EXSM.StateMachine{} = state_machine} =
      EXSM.new(TerminalStateIgnore, initial_states: [:one])
    assert %EXSM.State{name: :one, terminal?: true} ==
             EXSM.StateMachine.current_state(state_machine)
    assert true == EXSM.StateMachine.terminal?(state_machine)
    assert {:ok, state_machine, []} ==
             EXSM.process_event(TerminalStateIgnore, state_machine, :event)
  end

  test "terminal state machine error" do
    {:ok, %EXSM.StateMachine{} = state_machine} =
      EXSM.new(TerminalStateError, initial_states: [:one])
    assert %EXSM.State{name: :one, terminal?: true} ==
             EXSM.StateMachine.current_state(state_machine)
    assert true == EXSM.StateMachine.terminal?(state_machine)
    assert {:error, :no_transition, [state_machine: state_machine]} ==
             EXSM.process_event(TerminalStateError, state_machine, :event)
  end

  test "terminal state machine no_function_match" do
    {:ok, %EXSM.StateMachine{} = state_machine} =
      EXSM.new(TerminalStateNoFunctionMatch, initial_states: [:one])
    assert %EXSM.State{name: :one, terminal?: true} ==
             EXSM.StateMachine.current_state(state_machine)
    assert true == EXSM.StateMachine.terminal?(state_machine)

    assert_raise(CaseClauseError,
      fn ->
        EXSM.process_event(TerminalStateNoFunctionMatch, state_machine, :event)
      end)
  end
end
