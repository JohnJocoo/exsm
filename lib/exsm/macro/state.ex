defmodule EXSM.Macro.State do
  @moduledoc false

  @type ast :: tuple()

  @type t :: %__MODULE__{
               state: EXSM.State.t(),
               on_enter: ast() | nil,
               on_leave: ast() | nil,
               id: atom()
             }
  defstruct [:state, :on_enter, :on_leave, :id]
end
