defmodule EXSM.PlayerTest do
  use ExUnit.Case

  defmodule PlayerSM do

    def start_payback, do: :ok
    def pause_playback, do: :ok
    def resume_playback, do: :ok
    def stop_playback, do: :ok
    def open_drawer, do: :ok
    def close_drawer, do: :ok

    def store_cd_info({:cd_detected, good?, format}), do: :ok
    def good_disk?({:cd_detected, good?, format}), do: good?
    def auto_start?({:config, config}), do: Map.get(config, :auto_start, false)

  end

  defmodule PlayerSM do
    #use EXSM,
    def fun() do
    %{
      states: [:stopped, :open, :empty, :playing, :paused],
      events: [:play, :open_close, :stop, :cd_detected, :pause],
      transitions: [
        {:stopped, :play,        :playing, action: Player.start_payback/0},
        {:stopped, :open_close,  :open,    action: Player.open_drawer/0},
        {:stopped, :stop,        :stopped},

        {:open,    :open_close,  :empty,   action: Player.close_drawer/0},

        {:empty,   :cd_detected, :stopped, guard: Player.good_disk?/1,  action: Player.store_cd_info/1},
        {:empty,   :cd_detected, :playing, guard: Player.auto_start?/1, action: Player.store_cd_info/1},

        {:playing, :stop,        :stopped, action: Player.stop_playback/0},
        {:playing, :pause,       :paused,  action: Player.pause_playback/0},
        {:playing, :open_close,  :open,    action: [Player.stop_playback/0, Player.open_drawer/0]},

        {:paused,  :pause,       :playing, action: Player.resume_playback/0},
        {:paused,  :stop,        :stopped, action: Player.stop_playback/0},
        {:paused,  :open_close,  :open,    action: [Player.stop_playback/0, Player.open_drawer/0]}
      ]
    }
    end

  end

  test "greets the world" do
    assert EXSM.hello() == :world
  end
end