defmodule EXSM.State do
  @moduledoc false

  @enforce_keys [:name]
  defstruct [
    :name,
    description: nil,
    initial?: false
  ]

end
