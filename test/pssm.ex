defmodule PSSM do

  alias EXSM.Test.Callbacks

  defmacro __using__(_) do
    quote do
      use ExUnit.Case, async: false

      import unquote(__MODULE__)
      import EXSM.Test.Callbacks
      import Mock
    end
  end

  defmacro test_pssm(opts) when is_list(opts) do
    module = Keyword.fetch!(opts, :state_machine)
    events = Keyword.fetch!(opts, :events)
    test_name = "#{parse_module(module) |> inspect()} with events #{inspect(events)}"
    quote do
      test_with_callbacks_mock unquote(test_name) do
        {:ok, %EXSM.StateMachine{} = state_machine} = EXSM.new(unquote(module))
        updated_state_machine =
          Enum.reduce(unquote(events), state_machine, fn event, state_machine ->
            {:ok, %EXSM.StateMachine{} = updated_state_machine, _} =
              EXSM.process_event(unquote(module), state_machine, event)
            updated_state_machine
          end)
        assert EXSM.StateMachine.terminal?(updated_state_machine)
        assert :ok == EXSM.terminate(unquote(module), updated_state_machine)
        assert unquote(Keyword.get(opts, :expected_log, [])) ==
                call_history(unquote(EXSM.Test.Callbacks))
                |> PSSM.history()
      end
    end
  end

  def history(calls) do
    Enum.map(calls, fn {_, call, _} ->
      case call do
        {Callbacks, :leave_state_noreply, [id, nil, nil, nil]} ->
          {:leave, id}

        {Callbacks, :action_noreply, [id, nil, nil, nil]} ->
          {:action, id}
      end
    end)
  end

  def log_action(id), do: Callbacks.action_noreply(id, nil, nil, nil)
  def log_leave(id), do: Callbacks.leave_state_noreply(id, nil, nil, nil)

  defp parse_module({:__aliases__, _, modules}) when is_list(modules) do
    modules
  end

  defp parse_module(module) when is_atom(module) do
    module
  end
end