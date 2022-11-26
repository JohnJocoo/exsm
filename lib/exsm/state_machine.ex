defmodule EXSM.StateMachine do
  @moduledoc false

  @type t :: %__MODULE__{
               module: module(),
               current_state: EXSM.State.t(),
               user_state: any()
             }
  defstruct [:module, :current_state, :user_state]

  @spec new(module(), EXSM.State.t(), Keyword.t()) :: __MODULE__.t()
  def new(module, initial_state, opts) do
    %__MODULE__{
      module: module,
      current_state: initial_state,
      user_state: Keyword.get(opts, :user_state)
    }
  end

  @spec current_state(__MODULE__.t()) :: EXSM.State.t()
  def current_state(%__MODULE__{current_state: state}) do
    state
  end

  @spec user_state(__MODULE__.t()) :: any()
  def user_state(%__MODULE__{user_state: user_state}) do
    user_state
  end

  @spec update_current_state(__MODULE__.t(), EXSM.State.t()) :: __MODULE__.t()
  def update_current_state(%__MODULE__{} = state_machine, current_state) do
    %__MODULE__{state_machine | current_state: current_state}
  end

  @spec update_user_state(__MODULE__.t(), any()) :: __MODULE__.t()
  def update_user_state(%__MODULE__{} = state_machine, user_state) do
    %__MODULE__{state_machine | user_state: user_state}
  end
end