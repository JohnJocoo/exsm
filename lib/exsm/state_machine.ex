defmodule EXSM.StateMachine do
  @moduledoc false

  @type region :: atom()

  @type t :: %__MODULE__{
               module: module(),
               current_states: %{region() => EXSM.State.t()},
               current_state_ids: %{region() => atom()},
               user_state: any()
             }
  @enforce_keys [:module, :current_states, :current_state_ids, :user_state]
  defstruct [:module, :current_states, :current_state_ids, :user_state]

  @spec new(module(), [{atom(), EXSM.State.t()}], Keyword.t()) :: __MODULE__.t()
  def new(module, initial_states, opts) when is_atom(module) and length(initial_states) > 0 do
    repeated_regions =
      Enum.frequencies_by(initial_states, fn {_, %EXSM.State{region: region}} -> region end)
      |> Enum.filter(fn {_, count} -> count > 1 end)
    case repeated_regions do
      [] ->
        states_map = Map.new(initial_states, fn {_, %EXSM.State{region: region} = state} -> {region, state} end)
        ids_map = Map.new(initial_states, fn {id, %EXSM.State{region: region}} -> {region, id} end)
        %__MODULE__{
          module: module,
          current_states: states_map,
          current_state_ids: ids_map,
          user_state: Keyword.get(opts, :user_state)
        }

      _ ->
        {region, _} = List.first(repeated_regions)
        repeated_states =
          Enum.filter(initial_states, fn
            {_, %EXSM.State{region: ^region}} -> true
            {_, %EXSM.State{}} -> false
          end)
          |> Enum.map(fn {_, %EXSM.State{name: name}} -> name end)
        raise(ArgumentError,
          "initial states in the same region #{region} found #{inspect(repeated_states)} for module #{module}")
    end
  end

  @spec all_current_states(__MODULE__.t()) :: [EXSM.State.t()]
  def all_current_states(%__MODULE__{current_states: states}) do
    Map.values(states)
  end

  @spec current_state(__MODULE__.t(), region() | nil) :: EXSM.State.t()
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

  @spec current_state_id(__MODULE__.t(), region() | nil) :: atom()
  def current_state_id(state_machine, region \\ nil)

  def current_state_id(%__MODULE__{current_state_ids: %{nil => id}}, nil) do
    id
  end

  def current_state_id(%__MODULE__{current_state_ids: ids}, region) do
    Map.fetch!(ids, region)
  end

  @spec user_state(__MODULE__.t()) :: any()
  def user_state(%__MODULE__{user_state: user_state}) do
    user_state
  end

  @spec update_current_state(__MODULE__.t(), {atom(), EXSM.State.t()}, region() | nil) :: __MODULE__.t()
  def update_current_state(state_machine, current_state, region \\ nil)

  def update_current_state(%__MODULE__{current_states: %{nil => _state}} = state_machine,
                           {current_state_id, %EXSM.State{} = current_state},
                           nil) do
    %__MODULE__{
      state_machine |
      current_states: %{nil => current_state},
      current_state_ids: %{nil => current_state_id}
    }
  end

  def update_current_state(%__MODULE__{current_states: states,
                                       current_state_ids: ids,
                                       module: module
                                      } = state_machine,
                           {current_state_id, %EXSM.State{} = current_state},
                           region) do
    case Map.has_key?(states, region) do
      false ->
        region_dbg = if region == nil, do: "nil", else: region
        raise ArgumentError, "region #{region_dbg} does not exist for state machine #{module}"

      true ->
        %__MODULE__{
          state_machine |
          current_states: Map.replace!(states, region, current_state),
          current_state_ids: Map.replace!(ids, region, current_state_id)
        }
    end
  end

  @spec update_user_state(__MODULE__.t(), any()) :: __MODULE__.t()
  def update_user_state(%__MODULE__{} = state_machine, user_state) do
    %__MODULE__{state_machine | user_state: user_state}
  end
end