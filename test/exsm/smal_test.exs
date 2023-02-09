defmodule EXSM.SMALTest do
  use ExUnit.Case, async: true

  require EXSM.SMAL

  test "defines __using__" do
    assert macro_exported?(EXSM.SMAL, :__using__, 1)
  end

  test "defines operator <-" do
    assert macro_exported?(EXSM.SMAL, :<-, 2)
  end

  test "defines action" do
    assert macro_exported?(EXSM.SMAL, :action, 1)
    assert macro_exported?(EXSM.SMAL, :action, 2)
  end
end
