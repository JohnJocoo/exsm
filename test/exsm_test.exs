defmodule EXSMTest do
  use ExUnit.Case
  doctest EXSM

  test "defines __using__" do
    assert macro_exported?(EXSM, :__using__, 1)
  end

  test "defines state" do
    assert macro_exported?(EXSM, :state, 1)
    assert macro_exported?(EXSM, :state, 2)
  end

  test "defines describe" do
    assert macro_exported?(EXSM, :describe, 1)
  end

  test "defines initial" do
    assert macro_exported?(EXSM, :initial, 1)
  end

  test "defines on_enter" do
    assert macro_exported?(EXSM, :on_enter, 1)
  end

  test "defines on_leave" do
    assert macro_exported?(EXSM, :on_leave, 1)
  end

  test "defines transitions" do
    assert macro_exported?(EXSM, :transitions, 1)
  end

  test "defines operator <-" do
    assert macro_exported?(EXSM, :<-, 2)
  end

  test "defines action" do
    assert macro_exported?(EXSM, :action, 1)
  end
end
