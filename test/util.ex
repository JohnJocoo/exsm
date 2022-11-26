defmodule EXSM.Test.Util do

  def transit_state(module, from, event, user_state \\ nil) do
    case apply(Module.concat(module, EXSMTransitions), :handle_event, [from, event, user_state]) do
      {:transition, {_from, to, nil}} ->
        to

      {:transition, {_from, to, action}} ->
        action.()
        to

      {:no_transition, :ignore} ->
        from

      {:no_transition, :reply} ->
        from

      {:no_transition, :error} ->
        :error
    end
  end

end