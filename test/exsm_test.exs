defmodule EXSMTest do
  use ExUnit.Case
  doctest EXSM

  test "greets the world" do
    assert EXSM.hello() == :world
  end
end
