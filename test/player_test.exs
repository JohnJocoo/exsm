defmodule EXSM.PlayerTest do
  use ExUnit.Case, async: false

  import Mock

  alias EXSM.PlayerTest.Player
  alias EXSM.Test.Util

  defmodule PlayerSM do
    use EXSM.SMAL
    use EXSM.Functions

    import EXSM.PlayerTest.Player, only: [is_good_disk: 1]

    state :stopped do
      initial false
      describe "Playback was stopped"
      on_enter &PlayerSM.enter_stopped/2
      on_leave &PlayerSM.leave_stopped/2
    end

    state :empty do
      initial true
      describe "No cd, also initial state"
      on_enter fn(_state, _event) -> Player.start_detecting() end
    end

    state :playing do
      describe "Playing a song now"
      on_enter do: Player.show_current_song()
    end

    state :open do
      describe "Drawer is open"
    end

    state :paused

    transitions do
      :empty <- {:cd_detected, disk, _} = event >>> :stopped when is_good_disk(disk)
        action do: Player.store_cd_info(event)

      :stopped <- :play >>> :playing
        action do: Player.start_playback()
      :stopped <- :open_close >>> :open
        action do: Player.open_drawer()
      :stopped <- :stop >>> :stopped

      :open <- :open_close >>> :empty
        action &Player.close_drawer/0

      :playing <- :stop >>> :stopped
        action do: Player.stop_playback()
      :playing <- :pause >>> :paused
        action do: Player.pause_playback()
      :playing <- :open_close >>> :open
        action do
          Player.stop_playback()
          Player.open_drawer()
        end

      :paused <- :pause >>> :playing
        action do: Player.resume_playback()
      :paused <- :stop >>> :stopped
        action do: Player.stop_playback()
      :paused <- :open_close >>> :open
        action do
          Player.stop_playback()
          Player.open_drawer()
        end
    end

    def enter_stopped(state, event), do: Player.function_1(state, event)
    def leave_stopped(state, event), do: Player.function_2(state, event)
  end

  defmacro assert_player_not_called(opts \\ []) do
    except_functions = Keyword.get(opts, :except, [])
    functions = [
      {:start_playback, 0},
      {:pause_playback, 0},
      {:resume_playback, 0},
      {:stop_playback, 0},
      {:open_drawer, 0},
      {:close_drawer, 0},
      {:start_detecting, 0},
      {:show_current_song, 0},
      {:store_cd_info, 1},
      {:function_1, 2},
      {:function_2, 2}
    ]
    |> Enum.reject(fn {function, _} -> function in except_functions end)
    |> Enum.map(fn {function, arity} ->
      {:assert_not_called, [import: Mock],
        [{
          {:., [], [
            {:__aliases__, [alias: EXSM.PlayerTest.Player], [:Player]},
            function]},
          [], List.duplicate(:_, arity)
        }]
      }
    end)

    {:__block__, [], functions}
  end

  test "defines states/0" do
    assert function_exported?(PlayerSM, :states, 0)
  end

  test "defines new/0" do
    assert function_exported?(PlayerSM, :new, 0)
  end

  test "defines new/1" do
    assert function_exported?(PlayerSM, :new, 1)
  end

  test "defines process_event/2" do
    assert function_exported?(PlayerSM, :process_event, 2)
  end

  test "defines terminate/1" do
    assert function_exported?(PlayerSM, :terminate, 1)
  end

  test "states/0 return all states" do
    states = PlayerSM.states()
    assert is_list(states)
    assert length(states) == 5
    assert MapSet.new(states) == MapSet.new([
             %EXSM.State{name: :stopped,
                         description: "Playback was stopped",
                         initial?: false},
             %EXSM.State{name: :empty,
                         description: "No cd, also initial state",
                         initial?: true},
             %EXSM.State{name: :playing,
                         description: "Playing a song now",
                         initial?: false},
             %EXSM.State{name: :open,
                         description: "Drawer is open",
                         initial?: false},
             %EXSM.State{name: :paused,
                         description: nil,
                         initial?: false}
           ])
  end

  test "new/0 returns default state machine" do
    {:ok, %EXSM.StateMachine{} = state_machine} = PlayerSM.new()
    assert %EXSM.State{
             name: :empty,
             description: "No cd, also initial state",
             initial?: true
           } == EXSM.StateMachine.current_state(state_machine)
    assert [%EXSM.State{
             name: :empty,
             description: "No cd, also initial state",
             initial?: true
           }] == EXSM.StateMachine.all_current_states(state_machine)
    assert nil == EXSM.StateMachine.user_state(state_machine)
  end

  test "new/1 returns state machine with states and user data" do
    {:ok, %EXSM.StateMachine{} = state_machine} =
      PlayerSM.new(initial_states: [:playing], user_state: {:state, "data"})
    assert %EXSM.State{
             name: :playing,
             description: "Playing a song now"
           } == EXSM.StateMachine.current_state(state_machine)
    assert [%EXSM.State{
             name: :playing,
             description: "Playing a song now"
           }] == EXSM.StateMachine.all_current_states(state_machine)
    assert {:state, "data"} == EXSM.StateMachine.user_state(state_machine)
  end

  test "process_event/2 :empty <- {:cd_detected, {:disk, true}, :data} >>> :stop" do
    {:ok, %EXSM.StateMachine{} = state_machine} = PlayerSM.new()
    assert %EXSM.State{
             name: :empty,
             description: "No cd, also initial state",
             initial?: true
           } == EXSM.StateMachine.current_state(state_machine)
    {:ok, %EXSM.StateMachine{} = updated_state_machine, _} =
      PlayerSM.process_event(state_machine, {:cd_detected, {:disk, true}, :data})
    assert %EXSM.State{
             name: :stopped,
             description: "Playback was stopped"
           } == EXSM.StateMachine.current_state(updated_state_machine)
  end

  test "terminate/1 returns :ok" do
    {:ok, %EXSM.StateMachine{} = state_machine} = PlayerSM.new()
    assert %EXSM.State{
             name: :empty,
             description: "No cd, also initial state",
             initial?: true
           } == EXSM.StateMachine.current_state(state_machine)
    assert :ok == PlayerSM.terminate(state_machine)
  end

  test "EXSMTransitions ':empty <- {:cd_detected, disk, _} >>> :stopped' go to :stopped on valid disk" do
    assert :stopped == Util.transit_state(PlayerSM, :empty, {:cd_detected, {:disk, true}, :mp3})
  end

  test "EXSMTransitions ':empty <- {:cd_detected, disk, _} >>> :stopped' stay on invalid disk" do
    assert :empty == Util.transit_state(PlayerSM, :empty, {:cd_detected, {:disk, false}, :mp3})
  end

  test "EXSMTransitions ':empty <- {:cd_detected, disk, _} >>> :stopped' stay on unknown message" do
    assert :empty == Util.transit_state(PlayerSM, :empty, :unknown)
  end

  test "EXSMTransitions ':stopped <- :play >>> :playing' go to :playing on :play" do
    assert :playing == Util.transit_state(PlayerSM, :stopped, :play)
  end

  test "EXSMTransitions ':stopped <- :open_close >>> :open' go to :open on :open_close" do
    assert :open == Util.transit_state(PlayerSM, :stopped, :open_close)
  end

  test "EXSMTransitions ':stopped <- :stop >>> :stopped' stay on :stop" do
    assert :stopped == Util.transit_state(PlayerSM, :stopped, :stop)
  end

  test "EXSMTransitions ':stopped <- event >>> to' stay on unknown event" do
    assert :stopped == Util.transit_state(PlayerSM, :stopped, :unknown)
  end

  test "EXSMTransitions ':open <- :open_close >>> :empty' go to :empty on :open_close" do
    assert :empty == Util.transit_state(PlayerSM, :open, :open_close)
  end

  test "EXSMTransitions ':open <- :open_close >>> :empty' stay on unknown event" do
    assert :open == Util.transit_state(PlayerSM, :open, :unknown)
  end

  test "EXSMTransitions ':playing <- :stop >>> :stopped' go to :stopped on :stop" do
    assert :stopped == Util.transit_state(PlayerSM, :playing, :stop)
  end

  test "EXSMTransitions ':playing <- :pause >>> :paused' go to :paused on :pause" do
    assert :paused == Util.transit_state(PlayerSM, :playing, :pause)
  end

  test "EXSMTransitions ':playing <- :open_close >>> :open' go to :open on :open_close" do
    assert :open == Util.transit_state(PlayerSM, :playing, :open_close)
  end

  test "EXSMTransitions ':playing <- event >>> to' stay on unknown event" do
    assert :playing == Util.transit_state(PlayerSM, :playing, :unknown)
  end

  test "EXSMTransitions ':paused <- :pause >>> :playing' go to :playing on :pause" do
    assert :playing == Util.transit_state(PlayerSM, :paused, :pause)
  end

  test "EXSMTransitions ':paused <- :stop >>> :stopped' go to :stopped on :stop" do
    assert :stopped == Util.transit_state(PlayerSM, :paused, :stop)
  end

  test "EXSMTransitions ':paused <- :open_close >>> :open' go to :open on :open_close" do
    assert :open == Util.transit_state(PlayerSM, :paused, :open_close)
  end

  test "EXSMTransitions ':paused <- event >>> to' stay on unknown event" do
    assert :paused == Util.transit_state(PlayerSM, :paused, :unknown)
  end

  test_with_mock "EXSMTransitions ':empty <- event >>> :stopped' Player.store_cd_info(event) called",
       Player, [:passthrough], [] do
    assert :stopped == Util.transit_state(PlayerSM, :empty, {:cd_detected, {:disk, true}, :mp3})
    assert_called_exactly(Player.store_cd_info({:cd_detected, {:disk, true}, :mp3}), 1)
    assert_called_exactly(Player.function_1(nil, {:cd_detected, {:disk, true}, :mp3}), 1)
    assert_player_not_called except: [:store_cd_info, :function_1]
  end

  test_with_mock "EXSMTransitions ':stopped <- :play >>> :playing' Player.start_playback() called",
                 Player, [:passthrough], [] do
    assert :playing == Util.transit_state(PlayerSM, :stopped, :play)
    assert_called_exactly(Player.start_playback(), 1)
    assert_called_exactly(Player.function_2(nil, :play), 1)
    assert_called_exactly(Player.show_current_song(), 1)
    assert_player_not_called except: [:start_playback, :function_2, :show_current_song]
  end

  test_with_mock "EXSMTransitions ':stopped <- :open_close >>> :open' Player.open_drawer() called",
                 Player, [:passthrough], [] do
    assert :open == Util.transit_state(PlayerSM, :stopped, :open_close)
    assert_called_exactly(Player.open_drawer(), 1)
    assert_called_exactly(Player.function_2(nil, :open_close), 1)
    assert_player_not_called except: [:open_drawer, :function_2]
  end

  test_with_mock "EXSMTransitions ':stopped <- :stop >>> :stopped' nothing is called",
                 Player, [:passthrough], [] do
    assert :stopped == Util.transit_state(PlayerSM, :stopped, :stop)
    assert_player_not_called()
  end

  test_with_mock "EXSMTransitions ':open <- :open_close >>> :empty' Player.close_drawer() called",
                 Player, [:passthrough], [] do
    assert :empty == Util.transit_state(PlayerSM, :open, :open_close)
    assert_called_exactly(Player.close_drawer(), 1)
    assert_called_exactly(Player.start_detecting(), 1)
    assert_player_not_called except: [:close_drawer, :start_detecting]
  end

  test_with_mock "EXSMTransitions ':playing <- :stop >>> :stopped' Player.stop_playback() called",
                 Player, [:passthrough], [] do
    assert :stopped == Util.transit_state(PlayerSM, :playing, :stop)
    assert_called_exactly(Player.stop_playback(), 1)
    assert_called_exactly(Player.function_1(nil, :stop), 1)
    assert_player_not_called except: [:stop_playback, :function_1]
  end

  test_with_mock "EXSMTransitions ':playing <- :pause >>> :paused' Player.pause_playback() called",
                 Player, [:passthrough], [] do
    assert :paused == Util.transit_state(PlayerSM, :playing, :pause)
    assert_called_exactly(Player.pause_playback(), 1)
    assert_player_not_called except: [:pause_playback]
  end

  test_with_mock "EXSMTransitions ':playing <- :open_close >>> :open' stop_playback(), open_drawer() called",
                 Player, [:passthrough], [] do
    assert :open == Util.transit_state(PlayerSM, :playing, :open_close)
    assert_called_exactly(Player.stop_playback(), 1)
    assert_called_exactly(Player.open_drawer(), 1)
    assert_player_not_called except: [:stop_playback, :open_drawer]
  end

  test_with_mock "EXSMTransitions ':paused <- :pause >>> :playing' Player.resume_playback() called",
                 Player, [:passthrough], [] do
    assert :playing == Util.transit_state(PlayerSM, :paused, :pause)
    assert_called_exactly(Player.resume_playback(), 1)
    assert_called_exactly(Player.show_current_song(), 1)
    assert_player_not_called except: [:resume_playback, :show_current_song]
  end

  test_with_mock "EXSMTransitions ':paused <- :stop >>> :stopped' Player.stop_playback() called",
                 Player, [:passthrough], [] do
    assert :stopped == Util.transit_state(PlayerSM, :paused, :stop)
    assert_called_exactly(Player.stop_playback(), 1)
    assert_called_exactly(Player.function_1(nil, :stop), 1)
    assert_player_not_called except: [:stop_playback, :function_1]
  end

  test_with_mock "EXSMTransitions ':paused <- :open_close >>> :open' stop_playback(), open_drawer() called",
                 Player, [:passthrough], [] do
    assert :open == Util.transit_state(PlayerSM, :paused, :open_close)
    assert_called_exactly(Player.stop_playback(), 1)
    assert_called_exactly(Player.open_drawer(), 1)
    assert_player_not_called except: [:stop_playback, :open_drawer]
  end

  test_with_mock "EXSMStatesMeta verify :empty functions",
                 Player, [:passthrough], [] do
    assert :empty == Util.get_state_id(PlayerSM, :empty)
    assert %EXSM.State{
             name: :empty,
             description: "No cd, also initial state",
             initial?: true
           } == Util.get_state_data(PlayerSM, :empty)
    assert nil == Util.enter_state(PlayerSM, :empty, nil)
    assert_called_exactly(Player.start_detecting(), 1)
    assert {:error, :no_leave} == Util.leave_state(PlayerSM, :empty, nil)
    assert_player_not_called except: [:start_detecting]
  end

  test_with_mock "EXSMStatesMeta verify :stopped functions",
                 Player, [:passthrough], [] do
    assert :stopped == Util.get_state_id(PlayerSM, :stopped)
    assert %EXSM.State{
             name: :stopped,
             description: "Playback was stopped",
             initial?: false
           } == Util.get_state_data(PlayerSM, :stopped)
    assert :user_state == Util.enter_state(PlayerSM, :stopped, :user_state, :event)
    assert_called_exactly(Player.function_1(:user_state, :event), 1)
    assert {:state, :data} == Util.leave_state(PlayerSM, :stopped, {:state, :data}, "event")
    assert_called_exactly(Player.function_2({:state, :data}, "event"), 1)
    assert_player_not_called except: [:function_1, :function_2]
  end

  test_with_mock "EXSMStatesMeta verify :playing functions",
                 Player, [:passthrough], [] do
    assert :playing == Util.get_state_id(PlayerSM, :playing)
    assert %EXSM.State{
             name: :playing,
             description: "Playing a song now",
             initial?: false
           } == Util.get_state_data(PlayerSM, :playing)
    assert :state == Util.enter_state(PlayerSM, :playing, :state)
    assert_called_exactly(Player.show_current_song(), 1)
    assert {:error, :no_leave} == Util.leave_state(PlayerSM, :playing, nil)
    assert_player_not_called except: [:show_current_song]
  end

  test_with_mock "EXSMStatesMeta verify :open functions",
                 Player, [:passthrough], [] do
    assert :open == Util.get_state_id(PlayerSM, :open)
    assert %EXSM.State{
             name: :open,
             description: "Drawer is open",
             initial?: false
           } == Util.get_state_data(PlayerSM, :open)
    assert {:error, :no_enter} == Util.enter_state(PlayerSM, :open, nil)
    assert_player_not_called()
    assert {:error, :no_leave} == Util.leave_state(PlayerSM, :open, nil)
    assert_player_not_called()
  end

  test_with_mock "EXSMStatesMeta verify :paused functions",
                 Player, [:passthrough], [] do
    assert :paused == Util.get_state_id(PlayerSM, :paused)
    assert %EXSM.State{
             name: :paused,
             description: nil,
             initial?: false
           } == Util.get_state_data(PlayerSM, :paused)
    assert {:error, :no_enter} == Util.enter_state(PlayerSM, :paused, nil)
    assert_player_not_called()
    assert {:error, :no_leave} == Util.leave_state(PlayerSM, :paused, nil)
    assert_player_not_called()
  end
end