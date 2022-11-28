defmodule EXSM.Util do
  @moduledoc false

  @type event :: any()
  @type on_enter_result :: {:noreply, EXSM.State.user_state()} |
                           {:error, any()}
  @type on_leave_result :: {:noreply, EXSM.State.user_state()} |
                           {:error, any()}

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

  def function_to_arity_2(function, function_ast) do
    arity =
      :erlang.fun_info(function)
      |> Keyword.fetch!(:arity)

    case arity do
      2 ->
        function_ast

      0 ->
        quote do
          fn _, _ ->
            function = unquote(function_ast)
            function.()
          end
        end
    end
  end

  def parent_module(module) do
    Module.split(module)
    |> Enum.drop(-1)
    |> Module.concat()
  end

  def handle_action(nil, user_state), do: {:noreply, user_state}

  def handle_action(action, user_state) do
    case action.() do
      :ok ->
        {:noreply, user_state}

      {:noreply, new_user_state} ->
        {:noreply, new_user_state}

      {:reply, reply} ->
        {:reply, reply, user_state}

      {:reply, reply, new_user_state} ->
        {:reply, reply, new_user_state}

      {:error, error} ->
        {:error, error}

      error ->
        {:error, error}
    end
  end

  def state_meta_by_name(module, name) do
    module.__info__(:attributes)
    |> Keyword.get(:states)
    |> Keyword.get(name)
  end

  def enter_state(current_state, user_state, event \\ nil)

  def enter_state(%EXSM.Macro.State{on_enter: nil}, user_state, _) do
    {:noreply, user_state}
  end

  def enter_state(%EXSM.Macro.State{on_enter: on_enter}, user_state, event) do
    on_enter.(user_state, event)
  end

  def leave_state(current_state, user_state, event \\ nil)

  def leave_state(%EXSM.Macro.State{on_leave: nil}, user_state, _) do
    {:noreply, user_state}
  end

  def leave_state(%EXSM.Macro.State{on_leave: on_leave}, user_state, event) do
    on_leave.(user_state, event)
  end

  defp function_arity_0_or_2(function) do
    arity =
      :erlang.fun_info(function)
      |> Keyword.fetch!(:arity)

    arity == 0 or arity == 2
  end
end
