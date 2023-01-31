defmodule EXSM.State do
  @moduledoc false

  @type name :: any()
  @type user_state :: any()

  @type t :: %EXSM.State{
               name: name(),
               description: String.t(),
               initial?: boolean(),
               terminal?: boolean(),
               region: atom() | nil,
               sub_state_machine?: boolean(),
               _sub_state_machine: %EXSM.StateMachine{} | nil
             }
  @enforce_keys [:name]
  defstruct [
    :name,
    description: nil,
    initial?: false,
    terminal?: false,
    region: nil,
    sub_state_machine?: false,
    _sub_state_machine: nil
  ]

  def sub_state_machine(%__MODULE__{sub_state_machine?: false}) do
    {:error, :not_sub_state_machine}
  end

  def sub_state_machine(%__MODULE__{sub_state_machine?: true, _sub_state_machine: nil}) do
    {:error, :state_not_active}
  end

  def sub_state_machine(%__MODULE__{sub_state_machine?: true,
                                    _sub_state_machine: %EXSM.StateMachine{} = state_machine}) do
    {:ok, state_machine}
  end

end
