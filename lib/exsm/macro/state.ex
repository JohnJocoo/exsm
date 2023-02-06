defmodule EXSM.Macro.State do
  @moduledoc false

  @type ast :: tuple()

  @type t :: %__MODULE__{
               state: EXSM.State.t(),
               on_enter: ast() | nil,
               on_leave: ast() | nil,
               id: atom(),
               sub_machine_module: atom() | nil,
               sub_machine_init_opts: EXSM.new_state_machine_opts(),
               sub_machine_new: ast() | nil,
               sub_machine_terminate: ast() | nil
             }
  defstruct [
    :state,
    :on_enter,
    :on_leave,
    :id,
    :sub_machine_module,
    :sub_machine_init_opts,
    :sub_machine_new,
    :sub_machine_terminate
  ]
end
