defmodule EXSM.Test.Util do

  def transit_state(module, from, event, user_state \\ nil) do
    case apply(Module.concat(module, EXSMTransitions), :handle_event, [from, event, user_state]) do
      {:noreply, to, _new_user_state} -> to
      {:reply, to, _reply, _new_user_state} -> to
      {:error, _} = error -> error
    end
  end

end