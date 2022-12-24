defmodule EXSM.Test.Callbacks do

  alias EXSM.Test.Callbacks

  defmacro test_with_callbacks_mock(name, do: block) do
    quote do
      test_with_mock unquote(name), Callbacks, [:passthrough], [] do
        unquote(block)
      end
    end
  end

  def function_0(), do: {Callbacks, :function_0}
  def function_1(var), do: {Callbacks, :function_1, var}
  def function_2(var1, var2), do: {Callbacks, :function_2, var1, var2}
  def function_3(var1, var2, var3), do: {Callbacks, :function_3, var1, var2, var3}

  def enter_state_noreply(_id, _state, _event, new_state), do: {:noreply, new_state}
  def enter_state_error(_id, _state, _event), do: {:error, :test_enter}

  def leave_state_noreply(_id, _state, _event, new_state), do: {:noreply, new_state}
  def leave_state_error(_id, _state, _event), do: {:error, :test_leave}

  def action_noreply(_id, _state, _event, new_state), do: {:noreply, new_state}
  def action_reply(_id, _state, _event, reply, new_state), do: {:reply, reply, new_state}
  def action_error(_id, _state, _event), do: {:error, :test_action}
end
