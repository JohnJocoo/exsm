defmodule EXSM.Test.Util do

  def transit_state(module, from, event, user_state \\ nil) do
    case EXSM.Util.transition_info(module, from, event, user_state) do
      {:transition, {{^from, from_id}, {to_name, to_id}, action}} ->
        on_enter = EXSM.Util.on_enter_by_id(module, to_id)
        on_leave = EXSM.Util.on_leave_by_id(module, from_id)
        if from == to_name do
          EXSM.Util.handle_action(action, user_state)
        else
          EXSM.Util.leave_state(on_leave, user_state, event)
          EXSM.Util.handle_action(action, user_state)
          EXSM.Util.enter_state(on_enter, user_state, event)
        end
        to_name

      {:no_transition, :ignore} ->
        from

      {:no_transition, :reply} ->
        from

      {:no_transition, :error} ->
        :error
    end
  end

  def get_state_id(module, state_name) do
    {:ok, id} = EXSM.Util.state_id_by_name(module, state_name)
    id
  end

  def get_state_data(module, state_name) do
    {:ok, state, _id} = EXSM.Util.state_full_by_name(module, state_name)
    state
  end

  def enter_state(module, state_name, user_state, event \\ nil) do
    case EXSM.Util.state_id_by_name(module, state_name) do
      {:ok, id} ->
        function = EXSM.Util.on_enter_by_id(module, id)

        if function != nil do
          case EXSM.Util.enter_state(function, user_state, event) do
            {:noreply, state} -> state
            {:error, _} = error -> error
          end
        else
          {:error, :no_enter}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def leave_state(module, state_name, user_state, event \\ nil) do
    case EXSM.Util.state_id_by_name(module, state_name) do
      {:ok, id} ->
        function = EXSM.Util.on_leave_by_id(module, id)

        if function != nil do
          case EXSM.Util.leave_state(function, user_state, event) do
            {:noreply, state} -> state
            {:error, _} = error -> error
          end
        else
          {:error, :no_leave}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end