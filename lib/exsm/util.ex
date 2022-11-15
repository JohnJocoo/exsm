defmodule EXSM.Util do
  @moduledoc false

  def assert_state_function(function, context) do
    if not is_function(function) or
       not function_arity_0_or_2(function) do
      raise """
      #{context} should be a function of arity 0 or 2
      Examples:
      #{context}: &MyModule.on_enter_my_state/2
      #{context}: &MyModule.on_enter_my_state/0
      #{context}: fn(state, event) -> ... end
      #{context}: fn -> ... end
      """
    end
  end

  def function_to_arity_2(function) do
    arity =
      :erlang.fun_info(function)
      |> Keyword.fetch!(:arity)

    case arity do
      2 -> function
      0 -> fn _, _ -> function.() end
    end
  end

  def parent_module(module) do
    Module.split(module)
    |> Enum.drop(-1)
    |> Module.concat()
  end

  defp function_arity_0_or_2(function) do
    arity =
      :erlang.fun_info(function)
      |> Keyword.fetch!(:arity)

    arity == 0 or arity == 2
  end
end
