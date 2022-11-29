defmodule EXSM.Test.Util do

  def transit_state(module, from, event, user_state \\ nil) do
    case apply(Module.concat(module, EXSMTransitions), :handle_event, [from, event, user_state]) do
      {:transition, {_from, {to, _to_id}, nil}} ->
        to

      {:transition, {_from, {to, _to_id}, action}} ->
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

  def get_state_id(module, state_name) do
    case apply(Module.concat(module, EXSMStatesMeta), :_exsm_find_id, [state_name]) do
      {:ok, id} -> id
      {:error, :not_found} -> nil
    end
  end

  def get_state_data(module, state_name) do
    case apply(Module.concat(module, EXSMStatesMeta), :_exsm_find_id, [state_name]) do
      {:ok, id} ->
        apply(Module.concat(module, EXSMStatesMeta), id, [:state])

      {:error, :not_found} ->
        nil
    end
  end

  def enter_state(module, state_name, user_state, event \\ nil) do
    case apply(Module.concat(module, EXSMStatesMeta), :_exsm_find_id, [state_name]) do
      {:ok, id} ->
        function = apply(Module.concat(module, EXSMStatesMeta), id, [:on_enter])

        if function != nil do
          case function.(user_state, event) do
            :ok -> user_state
            {:noreply, state} -> state
            {:error, _} = error -> error
            error -> {:error, error}
          end
        else
          {:error, :no_enter}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def leave_state(module, state_name, user_state, event \\ nil) do
    case apply(Module.concat(module, EXSMStatesMeta), :_exsm_find_id, [state_name]) do
      {:ok, id} ->
        function = apply(Module.concat(module, EXSMStatesMeta), id, [:on_leave])

        if function != nil do
          case function.(user_state, event) do
            :ok -> user_state
            {:noreply, state} -> state
            {:error, _} = error -> error
            error -> {:error, error}
          end
        else
          {:error, :no_leave}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

end