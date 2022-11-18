defmodule EXSM.PlayerTest do
  use ExUnit.Case, async: false

  import Mock

  alias EXSM.PlayerTest.Player
  alias EXSM.Test.Util

  defmodule PlayerSM do
    use EXSM

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

    def enter_stopped(_state, _event), do: :ok
    def leave_stopped(_state, _event), do: :ok
  end

  defmacro assert_player_not_called(opts \\ []) do
    except_functions = Keyword.get(opts, :except, [])
    functions = [
      :start_playback,
      :pause_playback,
      :resume_playback,
      :stop_playback,
      :open_drawer,
      :close_drawer,
      :start_detecting,
      :show_current_song,
      :store_cd_info
    ]
    |> Enum.reject(&(&1 in except_functions))
    |> Enum.map(fn function ->
      {:assert_not_called, [import: Mock],
        [{{:., [], [{:__aliases__, [alias: EXSM.PlayerTest.Player], [:Player]}, function]}, [], [:_]}]}
    end)

    {:__block__, [], functions}
  end

  test "defines states()" do
    assert function_exported?(PlayerSM, :states, 0)
  end

  test "states() return all states" do
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
    assert_player_not_called except: [:store_cd_info]
  end

  test_with_mock "EXSMTransitions ':stopped <- :play >>> :playing' Player.start_playback() called",
                 Player, [:passthrough], [] do
    assert :playing == Util.transit_state(PlayerSM, :stopped, :play)
    assert_called_exactly(Player.start_playback(), 1)
    assert_player_not_called except: [:start_playback]
  end

  test_with_mock "EXSMTransitions ':stopped <- :open_close >>> :open' Player.open_drawer() called",
                 Player, [:passthrough], [] do
    assert :open == Util.transit_state(PlayerSM, :stopped, :open_close)
    assert_called_exactly(Player.open_drawer(), 1)
    assert_player_not_called except: [:open_drawer]
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
    assert_player_not_called except: [:close_drawer]
  end

  test_with_mock "EXSMTransitions ':playing <- :stop >>> :stopped' Player.stop_playback() called",
                 Player, [:passthrough], [] do
    assert :stopped == Util.transit_state(PlayerSM, :playing, :stop)
    assert_called_exactly(Player.stop_playback(), 1)
    assert_player_not_called except: [:stop_playback]
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
    assert_player_not_called except: [:resume_playback]
  end

  test_with_mock "EXSMTransitions ':paused <- :stop >>> :stopped' Player.stop_playback() called",
                 Player, [:passthrough], [] do
    assert :stopped == Util.transit_state(PlayerSM, :paused, :stop)
    assert_called_exactly(Player.stop_playback(), 1)
    assert_player_not_called except: [:stop_playback]
  end

  test_with_mock "EXSMTransitions ':paused <- :open_close >>> :open' stop_playback(), open_drawer() called",
                 Player, [:passthrough], [] do
    assert :open == Util.transit_state(PlayerSM, :paused, :open_close)
    assert_called_exactly(Player.stop_playback(), 1)
    assert_called_exactly(Player.open_drawer(), 1)
    assert_player_not_called except: [:stop_playback, :open_drawer]
  end
end