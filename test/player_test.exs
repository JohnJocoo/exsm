defmodule EXSM.PlayerTest do
  use ExUnit.Case

  alias EXSM.Test.Util

  defmodule Player do

    def start_payback, do: :ok
    def pause_playback, do: :ok
    def resume_playback, do: :ok
    def stop_playback, do: :ok
    def open_drawer, do: :ok
    def close_drawer, do: :ok
    def start_detecting, do: :ok
    def show_current_song, do: :ok

    def store_cd_info({:cd_detected, _disk, _format}), do: :ok
    defguard is_good_disk(disk) when is_tuple(disk) and elem(disk, 0) == :disk and elem(disk, 1)

  end

  defmodule PlayerSM do
    use EXSM

    import Player, only: [is_good_disk: 1]

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
        action do: Player.start_payback()
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
end