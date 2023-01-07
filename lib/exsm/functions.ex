defmodule EXSM.Functions do
  @moduledoc """
  Documentation for `EXSM.Functions`.
  """

  @all_functions [:states, :new, :process_event, :terminate]

  # opts:
  #   [:states | :new | :process_event | :terminate]
  defmacro __using__(functions \\ @all_functions) when is_list(functions) do
    allowed_functions = @all_functions
    Enum.each(functions, fn function ->
      if not Enum.member?(allowed_functions, function) do
        raise """
        Function #{inspect function} does not exists for #{__MODULE__}.
        Allowed values are #{inspect allowed_functions}
        """
      end
    end)

    quote do
      if unquote(Enum.member?(allowed_functions, :states)) do
        @spec states() :: [EXSM.State.t()]
        def states() do
          EXSM.states(__MODULE__)
        end
      end

      if unquote(Enum.member?(allowed_functions, :new)) do
        @spec new(EXSM.StateMachine.new_state_machine_opts()) ::
                {:ok, EXSM.StateMachine.t()} | {:error, any()}
        def new(opts \\ []) do
          EXSM.new(__MODULE__, opts)
        end
      end

      if unquote(Enum.member?(allowed_functions, :process_event)) do
        @spec process_event(EXSM.StateMachine.t(), EXSM.Util.event()) ::
                {:ok, EXSM.StateMachine.t(), EXSM.ok_details()} |
                {:ok, EXSM.StateMachine.t(), :no_transition | EXSM.reply(), EXSM.ok_details()} |
                {:error, :no_transition | any(), EXSM.error_details()}
        def process_event(state_machine, event) do
          EXSM.process_event(__MODULE__, state_machine, event)
        end
      end

      if unquote(Enum.member?(allowed_functions, :terminate)) do
        @spec terminate(EXSM.StateMachine.t()) ::
                :ok | {:error, [{EXSM.StateMachine.region(), any()}]}
        def terminate(state_machine) do
          EXSM.terminate(__MODULE__, state_machine)
        end
      end
    end
  end
end
