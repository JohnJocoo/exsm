defmodule EXSM.PlayerTest.Player do

  def start_playback, do: :ok
  def pause_playback, do: :ok
  def resume_playback, do: :ok
  def stop_playback, do: :ok
  def open_drawer, do: :ok
  def close_drawer, do: :ok
  def start_detecting, do: :ok
  def show_current_song, do: :ok
  def store_cd_info({:cd_detected, _disk, _format}), do: :ok
  def function_1(_, _), do: :ok
  def function_2(_, _), do: :ok

  defguard is_good_disk(disk) when is_tuple(disk) and elem(disk, 0) == :disk and elem(disk, 1)
end
