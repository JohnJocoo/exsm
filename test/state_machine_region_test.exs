defmodule EXSM.StateMachineRegionTest do
  use ExUnit.Case

  alias EXSM.State
  alias EXSM.StateMachine
  alias EXSM.Region

  defmodule TestM do

  end

  defmodule NoRegions do
    use EXSM

    state :initial, do: initial true
  end

  defmodule OneRegion do
    use EXSM

    region :main do
      state :initial, do: initial true
    end
  end

  defmodule ThreeRegions do
    use EXSM

    region :region_1 do
      state :stopped, do: initial true
    end

    region :region_2 do
      state :normal, do: initial true
    end

    region :region_3 do
      state :support, do: initial true
    end
  end

  defmodule TwoRegionsOneInitial do
    use EXSM

    region :region_1 do
      state :stopped, do: initial true
    end

    region :region_2 do
      state :normal
    end
  end

  test "regions no regions declared" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(NoRegions)
    assert [%Region{name: nil}] == StateMachine.regions(state_machine)
  end

  test "regions one region declared" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(OneRegion)
    assert [%Region{name: :main}] == StateMachine.regions(state_machine)
  end

  test "regions three region declared" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(ThreeRegions)
    assert [
             %Region{name: :region_1},
             %Region{name: :region_2},
             %Region{name: :region_3}
           ] == StateMachine.regions(state_machine)
  end

  test "create with two regions, but only one initial state" do
    assert_raise(ArgumentError,
      ~r/no initial state is provided for region .?region_2(\n| ).*TwoRegionsOneInitial.*/,
      fn ->
        EXSM.new(TwoRegionsOneInitial)
      end)
  end

  test "create with two regions, but only one initial state, provide initial states" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(TwoRegionsOneInitial,
      initial_states: [:normal, :stopped])
    assert [
             %Region{name: :region_1},
             %Region{name: :region_2}
           ] == StateMachine.regions(state_machine)
    assert %State{name: :stopped, initial?: true, region: :region_1} ==
             StateMachine.current_state(state_machine, :region_1)
    assert %State{name: :normal, region: :region_2} ==
             StateMachine.current_state(state_machine, :region_2)
  end

  test "create with two regions, but only one initial state, provide initial states and regions" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(TwoRegionsOneInitial,
      regions: [:region_2, :region_1], initial_states: [:normal, :stopped])
    assert [
             %Region{name: :region_2},
             %Region{name: :region_1}
           ] == StateMachine.regions(state_machine)
    assert %State{name: :stopped, initial?: true, region: :region_1} ==
             StateMachine.current_state(state_machine, :region_1)
    assert %State{name: :normal, region: :region_2} ==
             StateMachine.current_state(state_machine, :region_2)
  end

  test "create with two regions, but only one initial state, provide one region" do
    {:ok, %StateMachine{} = state_machine} = EXSM.new(TwoRegionsOneInitial,
      regions: [:region_1])
    assert [
             %Region{name: :region_1}
           ] == StateMachine.regions(state_machine)
    assert %State{name: :stopped, initial?: true, region: :region_1} ==
             StateMachine.current_state(state_machine, :region_1)
  end

  test "create with one state with region" do
    state_machine = StateMachine.new(
      TestM,
      [{:empty, %State{name: :empty, region: :default}}],
      [regions: [%Region{name: :default}]]
    )
    assert [%State{name: :empty, region: :default}] == StateMachine.all_current_states(state_machine)
    assert %State{name: :empty, region: :default} == StateMachine.current_state(state_machine, :default)
    assert :empty == StateMachine.current_state_id(state_machine, :default)
  end

  test "create with two orthogonal states" do
    state_1 = %State{name: :normal, region: :main}
    state_2 = %State{name: :empty, region: :player}
    state_machine = StateMachine.new(
      TestM,
      [{:normal, state_1}, {:empty, state_2}],
      [regions: [%Region{name: :main}, %Region{name: :player}]]
    )
    all_states = StateMachine.all_current_states(state_machine)
    assert state_1 in all_states
    assert state_2 in all_states
    assert state_1 == StateMachine.current_state(state_machine, :main)
    assert state_2 == StateMachine.current_state(state_machine, :player)
    assert :normal == StateMachine.current_state_id(state_machine, :main)
    assert :empty == StateMachine.current_state_id(state_machine, :player)
    assert nil == StateMachine.user_state(state_machine)
  end

  test "create with three states, but only 2 regions" do
    state_1 = %State{name: :normal, region: :main}
    state_2 = %State{name: :empty, region: :player}
    state_3 = %State{name: :failed, region: :main}
    assert_raise(ArgumentError,
      ~r/initial states in the same region .?main found(\n| ).*(normal|failed).*(normal|failed).*TestM.*/,
      fn ->
        StateMachine.new(
          TestM,
          [{:normal, state_1}, {:empty, state_2}, {:failed, state_3}],
          [regions: [%Region{name: :main}, %Region{name: :player}]]
        )
      end)
  end

  test "current_state with non-existing region" do
    state_machine_one_state = StateMachine.new(TestM, [{:empty, %State{name: :empty}}], [])
    assert_raise(ArgumentError,
      ~r/region .?main does not exist for state machine .*TestM.*/,
      fn -> StateMachine.current_state(state_machine_one_state, :main) end)
    assert_raise(KeyError,
      fn -> StateMachine.current_state_id(state_machine_one_state, :main) end)
    state_1 = %State{name: :normal, region: :main}
    state_2 = %State{name: :empty, region: :player}
    state_machine_orthogonal = StateMachine.new(
      TestM,
      [{:normal, state_1}, {:empty, state_2}],
      [regions: [%Region{name: :main}, %Region{name: :player}]]
    )
    assert_raise(ArgumentError,
      ~r/region .?default does not exist for state machine .*TestM.*/,
      fn -> StateMachine.current_state(state_machine_orthogonal, :default) end)
    assert_raise(ArgumentError,
      ~r/region .?nil does not exist for state machine .*TestM.*/,
      fn -> StateMachine.current_state(state_machine_orthogonal, nil) end)
    assert_raise(KeyError,
      fn -> StateMachine.current_state_id(state_machine_orthogonal, :default) end)
    assert_raise(KeyError,
      fn -> StateMachine.current_state_id(state_machine_orthogonal, nil) end)
  end

  test "update one sm state with region" do
    initial_state = %State{name: :empty, region: :default}
    state_machine = StateMachine.new(
      TestM,
      [{:empty, initial_state}],
      [regions: [%Region{name: :default}]]
    )
    assert initial_state == StateMachine.current_state(state_machine, :default)
    assert :empty == StateMachine.current_state_id(state_machine, :default)
    new_state = %State{name: :full, region: :default}
    updated_state_machine = StateMachine.update_current_state(state_machine, {:full, new_state}, :default)
    assert new_state == StateMachine.current_state(updated_state_machine, :default)
    assert :full == StateMachine.current_state_id(updated_state_machine, :default)
  end

  test "update sm two states with regions" do
    state_1 = %State{name: :normal, region: :main}
    state_2 = %State{name: :empty, region: :player}
    state_machine = StateMachine.new(
      TestM,
      [{:normal, state_1}, {:empty, state_2}],
      [regions: [%Region{name: :main}, %Region{name: :player}]]
    )
    assert state_1 == StateMachine.current_state(state_machine, :main)
    assert state_2 == StateMachine.current_state(state_machine, :player)
    assert :normal == StateMachine.current_state_id(state_machine, :main)
    assert :empty == StateMachine.current_state_id(state_machine, :player)

    updated_state_1 = %State{name: :failed, region: :main}
    updated_state_2 = %State{name: :full, region: :player}
    updated_state_machine = StateMachine.update_current_state(state_machine, {:failed, updated_state_1}, :main)
    assert updated_state_1 == StateMachine.current_state(updated_state_machine, :main)
    assert :failed == StateMachine.current_state_id(updated_state_machine, :main)
    updated_state_machine = StateMachine.update_current_state(updated_state_machine, {:full, updated_state_2}, :player)
    assert updated_state_2 == StateMachine.current_state(updated_state_machine, :player)
    assert :full == StateMachine.current_state_id(updated_state_machine, :player)
    all_states = StateMachine.all_current_states(updated_state_machine)
    assert updated_state_1 in all_states
    assert updated_state_2 in all_states
  end

  test "update sm states with non-existing regions" do
    state_machine = StateMachine.new(TestM, [{:empty, %State{name: :empty}}], [])
    assert %State{name: :empty} == StateMachine.current_state(state_machine)
    assert :empty == StateMachine.current_state_id(state_machine)
    region_state = %State{name: :full, region: :default}
    assert_raise(ArgumentError,
      ~r/region .?default does not exist for state machine .*TestM.*/,
      fn -> StateMachine.update_current_state(state_machine, {:full, region_state}, :default) end)

    state_1 = %State{name: :normal, region: :main}
    state_2 = %State{name: :empty, region: :player}
    state_machine = StateMachine.new(
      TestM,
      [{:normal, state_1}, {:empty, state_2}],
      [regions: [%Region{name: :main}, %Region{name: :player}]]
    )
    assert state_1 == StateMachine.current_state(state_machine, :main)
    assert state_2 == StateMachine.current_state(state_machine, :player)
    assert :normal == StateMachine.current_state_id(state_machine, :main)
    assert :empty == StateMachine.current_state_id(state_machine, :player)
    assert_raise(ArgumentError,
      ~r/region .?default does not exist for state machine .*TestM.*/,
      fn -> StateMachine.update_current_state(state_machine, {:full, region_state}, :default) end)
  end
end
