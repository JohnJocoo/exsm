defmodule EXSM.Test.Callbacks do

  alias EXSM.Test.Callbacks

  def function_0(), do: {Callbacks, :function_0}
  def function_1(var), do: {Callbacks, :function_1, var}
  def function_2(var1, var2), do: {Callbacks, :function_2, var1, var2}
  def function_3(var1, var2, var3), do: {Callbacks, :function_3, var1, var2, var3}

end
