defmodule EXSM.StateMachine do
  @moduledoc false

  @type t :: %__MODULE__{
               module: module(),
               current_state: EXSM.State.name(),
               user_state: any()
             }
  defstruct [:module, :current_state, :user_state]

  @spec new(module(), EXSM.State.name(), Keyword.t()) :: __MODULE__.t()
  def new(module, initial_state, opts) do
    %__MODULE__{
      module: module,
      current_state: initial_state,
      user_state: Keyword.get(opts, :user_state)
    }
  end

end