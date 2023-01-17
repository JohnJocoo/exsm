defmodule EXSM.State do
  @moduledoc false

  @type name :: any()
  @type user_state :: any()

  @type t :: %EXSM.State{
               name: name(),
               description: String.t(),
               initial?: boolean(),
               terminal?: boolean(),
               region: atom() | nil
             }
  @enforce_keys [:name]
  defstruct [
    :name,
    description: nil,
    initial?: false,
    terminal?: false,
    region: nil
  ]

end
