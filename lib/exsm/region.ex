defmodule EXSM.Region do
  @moduledoc false

  @type t :: %EXSM.Region{
               name: atom(),
               description: String.t()
             }
  @enforce_keys [:name]
  defstruct [
    :name,
    description: nil
  ]
end
