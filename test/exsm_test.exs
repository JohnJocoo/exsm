defmodule EXSMTest do
  use ExUnit.Case
  doctest EXSM

  defmodule StatesNone do
    use EXSM
  end

  defmodule StatesOne do
    use EXSM

    state :one
  end

  defmodule StatesThree do
    use EXSM

    state :one
    state :two
    state :three
  end

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
    assert macro_exported?(EXSM, :on_enter, 2)
  end

  test "defines on_leave" do
    assert macro_exported?(EXSM, :on_leave, 1)
    assert macro_exported?(EXSM, :on_leave, 2)
  end

  test "defines transitions" do
    assert macro_exported?(EXSM, :transitions, 1)
  end

  test "defines operator <-" do
    assert macro_exported?(EXSM, :<-, 2)
  end

  test "defines action" do
    assert macro_exported?(EXSM, :action, 1)
    assert macro_exported?(EXSM, :action, 2)
  end

  test "states EXSMTest" do
    assert [] == EXSM.states(EXSMTest)
  end

  test "states StatesNone" do
    assert [] == EXSM.states(StatesNone)
  end

  test "states StatesOne" do
    assert [%EXSM.State{name: :one}] == EXSM.states(StatesOne)
  end

  test "states StatesThree" do
    assert 3 == length(EXSM.states(StatesThree))
    assert MapSet.new([
             %EXSM.State{name: :one},
             %EXSM.State{name: :two},
             %EXSM.State{name: :three}
           ]) == MapSet.new(EXSM.states(StatesThree))
  end
end
