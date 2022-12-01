defmodule EXSM.StateMachine do
  @moduledoc false

  @type t :: %__MODULE__{
               module: module(),
               current_states: %{atom() => EXSM.State.t()},
               user_state: any()
             }
  defstruct [:module, :current_states, :user_state]

  @spec new(module(), [EXSM.State.t()], Keyword.t()) :: __MODULE__.t()
  def new(module, initial_states, opts) when is_atom(module) and length(initial_states) > 0 do
    repeated_regions =
      Enum.frequencies_by(initial_states, &(&1.region))
      |> Enum.filter(fn {_, count} -> count > 1 end)
    case repeated_regions do
      [] ->
        states_map = Map.new(initial_states, fn %EXSM.State{region: region} = state -> {region, state} end)
        %__MODULE__{
          module: module,
          current_states: states_map,
          user_state: Keyword.get(opts, :user_state)
        }

      _ ->
        {region, _} = List.first(repeated_regions)
        repeated_states =
          Enum.filter(initial_states, fn
            %EXSM.State{region: ^region} -> true
            %EXSM.State{} -> false
          end)
          |> Enum.map(&(&1.name))
        raise(ArgumentError,
          "initial states in the same region #{region} found #{inspect(repeated_states)} for module #{module}")
    end

  end

  @spec all_current_states(__MODULE__.t()) :: [EXSM.State.t()]
  def all_current_states(%__MODULE__{current_states: states}) do
    Map.values(states)
  end

  @spec current_state(__MODULE__.t(), atom() | nil) :: EXSM.State.t()
  def current_state(state_machine, region \\ nil)

  def current_state(%__MODULE__{current_states: %{nil => state}}, nil) do
    state
  end

  def current_state(%__MODULE__{current_states: states, module: module}, region) do
    case Map.get(states, region) do
      nil ->
        region_dbg = if region == nil, do: "nil", else: region
        raise ArgumentError, "region #{region_dbg} does not exist for state machine #{module}"

      current_state ->
        current_state
    end
  end

  @spec user_state(__MODULE__.t()) :: any()
  def user_state(%__MODULE__{user_state: user_state}) do
    user_state
  end

  @spec update_current_state(__MODULE__.t(), EXSM.State.t(), atom() | nil) :: __MODULE__.t()
  def update_current_state(state_machine, current_state, region \\ nil)

  def update_current_state(%__MODULE__{current_states: %{nil => _state}} = state_machine,
                           %EXSM.State{} = current_state,
                           nil) do
    %__MODULE__{state_machine | current_states: %{nil => current_state}}
  end

  def update_current_state(%__MODULE__{current_states: states, module: module} = state_machine,
                           %EXSM.State{region: region} = current_state,
                           region) do
    case Map.has_key?(states, region) do
      false ->
        region_dbg = if region == nil, do: "nil", else: region
        raise ArgumentError, "region #{region_dbg} does not exist for state machine #{module}"

      true ->
        %__MODULE__{state_machine | current_states: Map.replace!(states, region, current_state)}
    end
  end

  @spec update_user_state(__MODULE__.t(), any()) :: __MODULE__.t()
  def update_user_state(%__MODULE__{} = state_machine, user_state) do
    %__MODULE__{state_machine | user_state: user_state}
  end
end