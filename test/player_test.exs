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
    def good_disk?({:disk, readable?}), do: readable?

  end

  defmodule PlayerSM do
    use EXSM

    state :stopped do
      describe "Playback was stopped"
      on_enter enter_stopped/2
      on_leave leave_stopped/2
    end

    state :empty do
      @initial
      describe "No cd, also initial state"
      on_enter fn(state, _event) -> Player.start_detecting() end
    end

    state :playing do
      describe "Playing a song now"
      on_enter do: Player.show_current_song()
    end

    state :open do
      describe "Drawer is open"
    end

    transitions do
      :empty <- {:cd_detected, disk, _} = event >>> :stopped when Player.good_disk?(disk)
        action do: Player.store_cd_info(event)

      :stopped <- :play >>> :playing
        action do: Player.start_payback()
      :stopped <- :open_close >>> :open
        action do: Player.open_drawer()
      :stopped <- :stop >>> :stopped

      :open <- :open_close >>> :empty
        action Player.close_drawer/0

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

    defp enter_stopped(state, _event), do: :ok
    defp leave_stopped(state, _event), do: :ok
  end

  test "greets the world" do
    assert EXSM.hello() == :world
  end
end