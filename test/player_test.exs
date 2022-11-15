defmodule EXSM.PlayerTest do
  use ExUnit.Case

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

    #IO.inspect(@states)
  end

  test "greets the world" do
    assert EXSM.hello() == :world
  end
end