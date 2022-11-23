defmodule EXSM.StateMachine do
  @moduledoc false

  @type t :: %__MODULE__{
               module: module(),
               states: %{EXSM.State.name() => EXSM.Macro.State.t()},
               current_state: EXSM.State.name(),
               user_state: any()
             }
  defstruct [:module, :states, :current_state, :user_state]


end