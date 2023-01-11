defmodule EXSM.TransitionsRegionTest do
  use ExUnit.Case

  import Mock
  import EXSM.Test.Callbacks

  alias EXSM.Test.Callbacks

  defmodule Test do
    use EXSM.SMAL

    region :top_region do
      state :top_state1, do: initial true
      state :top_state2
    end

    region :middle_region do
      state :middle_state1, do: initial true
      state :middle_state2
    end

    region :bottom_region do
      state :bottom_state1, do: initial true
      state :bottom_state2
    end

    transitions do
      :top_state1 <- :event >>> :top_state2
      :middle_state1 <- :event >>> :middle_state2
      :bottom_state1 <- :event >>> :bottom_state2
    end
  end

  defmodule TestCB do
    use EXSM.SMAL

    region :top_region do
      state :top_state1 do
        initial true
        on_enter do: Callbacks.enter_state_noreply(:top_state1, nil, nil, nil)
        on_leave do: Callbacks.leave_state_noreply(:top_state1, nil, nil, nil)
      end

      state :top_state2 do
        on_enter do: Callbacks.enter_state_noreply(:top_state2, nil, nil, nil)
        on_leave do: Callbacks.leave_state_noreply(:top_state2, nil, nil, nil)
      end
    end

    region :bottom_region do
      state :bottom_state1 do
        initial true
        on_enter do: Callbacks.enter_state_noreply(:bottom_state1, nil, nil, nil)
        on_leave do: Callbacks.leave_state_noreply(:bottom_state1, nil, nil, nil)
      end

      state :bottom_state2 do
        on_enter do: Callbacks.enter_state_noreply(:bottom_state2, nil, nil, nil)
        on_leave do: Callbacks.leave_state_noreply(:bottom_state2, nil, nil, nil)
      end
    end

    transitions do
      :bottom_state1 <- :event >>> :bottom_state2
        action do: Callbacks.action_noreply(:bottom_state1, nil, nil, nil)
      :top_state1 <- :event >>> :top_state2
        action do: Callbacks.action_noreply(:top_state1, nil, nil, nil)
    end
  end

  def call_only(calls) do
    Enum.map(calls, fn {_, call, _} -> call end)
  end

  test "transition priority by default" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(Test)
    assert [
             %EXSM.Region{name: :top_region},
             %EXSM.Region{name: :middle_region},
             %EXSM.Region{name: :bottom_region}
           ] == EXSM.StateMachine.regions(state_machine)
    assert %EXSM.State{name: :top_state1, initial?: true, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :middle_state1, initial?: true, region: :middle_region} ==
             EXSM.StateMachine.current_state(state_machine, :middle_region)
    assert %EXSM.State{name: :bottom_state1, initial?: true, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)

    {:ok, %EXSM.StateMachine{} = state_machine, _} = EXSM.process_event(Test, state_machine, :event)
    assert %EXSM.State{name: :top_state2, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :middle_state1, initial?: true, region: :middle_region} ==
             EXSM.StateMachine.current_state(state_machine, :middle_region)
    assert %EXSM.State{name: :bottom_state1, initial?: true, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)

    {:ok, %EXSM.StateMachine{} = state_machine, _} = EXSM.process_event(Test, state_machine, :event)
    assert %EXSM.State{name: :top_state2, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :middle_state2, region: :middle_region} ==
             EXSM.StateMachine.current_state(state_machine, :middle_region)
    assert %EXSM.State{name: :bottom_state1, initial?: true, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)

    {:ok, %EXSM.StateMachine{} = state_machine, _} = EXSM.process_event(Test, state_machine, :event)
    assert %EXSM.State{name: :top_state2, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :middle_state2, region: :middle_region} ==
             EXSM.StateMachine.current_state(state_machine, :middle_region)
    assert %EXSM.State{name: :bottom_state2, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)
  end

  test "transition priority custom regions order" do
    {:ok, %EXSM.StateMachine{} = state_machine} =
      EXSM.new(Test, regions: [:bottom_region, :top_region, :middle_region])
    assert [
             %EXSM.Region{name: :bottom_region},
             %EXSM.Region{name: :top_region},
             %EXSM.Region{name: :middle_region}
           ] == EXSM.StateMachine.regions(state_machine)
    assert %EXSM.State{name: :top_state1, initial?: true, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :middle_state1, initial?: true, region: :middle_region} ==
             EXSM.StateMachine.current_state(state_machine, :middle_region)
    assert %EXSM.State{name: :bottom_state1, initial?: true, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)

    {:ok, %EXSM.StateMachine{} = state_machine, _} = EXSM.process_event(Test, state_machine, :event)
    assert %EXSM.State{name: :top_state1, initial?: true, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :middle_state1, initial?: true, region: :middle_region} ==
             EXSM.StateMachine.current_state(state_machine, :middle_region)
    assert %EXSM.State{name: :bottom_state2, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)

    {:ok, %EXSM.StateMachine{} = state_machine, _} = EXSM.process_event(Test, state_machine, :event)
    assert %EXSM.State{name: :top_state2, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :middle_state1, initial?: true, region: :middle_region} ==
             EXSM.StateMachine.current_state(state_machine, :middle_region)
    assert %EXSM.State{name: :bottom_state2, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)

    {:ok, %EXSM.StateMachine{} = state_machine, _} = EXSM.process_event(Test, state_machine, :event)
    assert %EXSM.State{name: :top_state2, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :middle_state2, region: :middle_region} ==
             EXSM.StateMachine.current_state(state_machine, :middle_region)
    assert %EXSM.State{name: :bottom_state2, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)
  end

  test_with_callbacks_mock "transition priority by default, mock" do
    {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(TestCB)
    assert [
             %EXSM.Region{name: :top_region},
             %EXSM.Region{name: :bottom_region}
           ] == EXSM.StateMachine.regions(state_machine)
    assert %EXSM.State{name: :top_state1, initial?: true, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :bottom_state1, initial?: true, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)

    {:ok, %EXSM.StateMachine{} = state_machine, _} = EXSM.process_event(TestCB, state_machine, :event)
    assert %EXSM.State{name: :top_state2, region: :top_region} ==
             EXSM.StateMachine.current_state(state_machine, :top_region)
    assert %EXSM.State{name: :bottom_state1, initial?: true, region: :bottom_region} ==
             EXSM.StateMachine.current_state(state_machine, :bottom_region)

    :ok = EXSM.terminate(TestCB, state_machine)

    assert [
             {Callbacks, :enter_state_noreply, [:top_state1, nil, nil, nil]},
             {Callbacks, :enter_state_noreply, [:bottom_state1, nil, nil, nil]},
             {Callbacks, :leave_state_noreply, [:top_state1, nil, nil, nil]},
             {Callbacks, :action_noreply, [:top_state1, nil, nil, nil]},
             {Callbacks, :enter_state_noreply, [:top_state2, nil, nil, nil]},
             {Callbacks, :leave_state_noreply, [:bottom_state1, nil, nil, nil]},
             {Callbacks, :leave_state_noreply, [:top_state2, nil, nil, nil]}
           ] = call_history(Callbacks)
               |> call_only()
  end
end
