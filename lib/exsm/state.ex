defmodule EXSM.State do
  @moduledoc false

  @type t :: %EXSM.State{}

  @enforce_keys [:name]
  defstruct [
    :name,
    description: nil,
    initial?: false
  ]

end
