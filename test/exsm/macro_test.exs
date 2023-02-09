defmodule EXSM.MacroTest do
  use ExUnit.Case, async: true

  require EXSM.Macro

  test "defines state" do
    assert macro_exported?(EXSM.Macro, :state, 1)
    assert macro_exported?(EXSM.Macro, :state, 2)
  end

  test "defines describe" do
    assert macro_exported?(EXSM.Macro, :describe, 1)
  end

  test "defines initial" do
    assert macro_exported?(EXSM.Macro, :initial, 1)
  end

  test "defines terminal" do
    assert macro_exported?(EXSM.Macro, :terminal, 1)
  end

  test "defines on_enter" do
    assert macro_exported?(EXSM.Macro, :on_enter, 1)
    assert macro_exported?(EXSM.Macro, :on_enter, 2)
  end

  test "defines on_leave" do
    assert macro_exported?(EXSM.Macro, :on_leave, 1)
    assert macro_exported?(EXSM.Macro, :on_leave, 2)
  end

  test "defines transitions" do
    assert macro_exported?(EXSM.Macro, :transitions, 1)
  end
end
