defmodule EXSM.Util do
  @moduledoc false

  @type event :: any()
  @type on_enter_result :: :ok |
                           {:noreply, EXSM.State.user_state()} |
                           {:error, any()} |
                           any()
  @type on_leave_result :: :ok |
                           {:noreply, EXSM.State.user_state()} |
                           {:error, any()} |
                           any()
  @type action_result :: :ok |
                         {:noreply, EXSM.State.user_state()} |
                         {:reply, any()} |
                         {:reply, any(), EXSM.State.user_state()} |
                         {:error, any()} |
                         any()
  @type on_enter_result_mapped :: {:noreply, EXSM.State.user_state()} |
                                  {:error, any()}
  @type on_leave_result_mapped :: {:noreply, EXSM.State.user_state()} |
                                  {:error, any()}
  @type action_result_mapped :: {:noreply, EXSM.State.user_state()} |
                                {:reply, any(), EXSM.State.user_state()} |
                                {:error, any()}
  @type on_enter_callback :: (EXSM.State.user_state(), event() -> on_enter_result())
  @type on_leave_callback :: (EXSM.State.user_state(), event() -> on_leave_result())
  @type action_callback :: (EXSM.State.user_state() -> action_result())
  @type transition_result :: {:transition, {
                                {EXSM.State.name(), atom()},
                                {EXSM.State.name(), atom()},
                                action_callback() | nil}
                             } |
                             {:no_transition, :ignore | :reply | :error}

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
    :ok
  end

  def assert_only_allowed_keywords(opts, allowed, context) do
    case Enum.find(opts, fn {key, _} -> key not in allowed end) do
      nil ->
        :ok

      {key, _} ->
        raise "#{key} is not allowed in options for #{context}"
    end
  end

  @spec function_to_arity_2((any(), any() -> any()) | ( -> any()), EXSM.Macro.ast()) :: EXSM.Macro.ast()
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

  @spec parent_module(module()) :: module()
  def parent_module(module) do
    Module.split(module)
    |> Enum.drop(-1)
    |> Module.concat()
  end

  @spec state_full_by_name(module(), any()) :: {:ok, EXSM.State.t(), atom()} | {:error, :not_found}
  def state_full_by_name(module, name) do
    state_module = Module.concat(module, EXSMStatesMeta)
    case apply(state_module, :_exsm_find_id, [name]) do
      {:ok, id} ->
        {:ok, apply(state_module, id, [:state]), id}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @spec state_id_by_name(module(), any()) :: {:ok, atom()} | {:error, :not_found}
  def state_id_by_name(module, name) do
    apply(Module.concat(module, EXSMStatesMeta), :_exsm_find_id, [name])
  end

  @spec state_by_id(module(), atom()) :: EXSM.State.t()
  def state_by_id(module, id) do
    apply(Module.concat(module, EXSMStatesMeta), id, [:state])
  end

  @spec on_enter_by_id(module(), atom()) :: on_enter_callback() | nil
  def on_enter_by_id(module, id) do
    apply(Module.concat(module, EXSMStatesMeta), id, [:on_enter])
  end

  @spec on_leave_by_id(module(), atom()) :: on_leave_callback() | nil
  def on_leave_by_id(module, id) do
    apply(Module.concat(module, EXSMStatesMeta), id, [:on_leave])
  end

  @spec transition_info(module(), EXSM.State.name(), event(), EXSM.State.user_state()) :: transition_result()
  def transition_info(module, %EXSM.State{name: name}, event, user_state) do
    transition_info(module, name, event, user_state)
  end

  def transition_info(module, from, event, user_state) do
    apply(Module.concat(module, EXSMTransitions), :handle_event, [from, event, user_state])
  end

  @spec handle_action(action_callback() | nil, EXSM.State.user_state()) :: action_result_mapped()
  def handle_action(nil, user_state), do: {:noreply, user_state}

  def handle_action(action, user_state) do
    case action.(user_state) do
      :ok -> {:noreply, user_state}
      {:noreply, new_user_state} -> {:noreply, new_user_state}
      {:reply, reply} -> {:reply, reply, user_state}
      {:reply, reply, new_user_state} -> {:reply, reply, new_user_state}
      {:error, error} -> {:error, error}
      error -> {:error, error}
    end
  end

  @spec enter_state(on_enter_callback() | nil, EXSM.State.user_state(), event() | nil) :: on_enter_result_mapped()
  def enter_state(on_enter, user_state, event \\ nil)

  def enter_state(nil, user_state, _), do: {:noreply, user_state}

  def enter_state(on_enter, user_state, event) do
    case on_enter.(user_state, event) do
      :ok -> {:noreply, user_state}
      {:noreply, new_user_state} -> {:noreply, new_user_state}
      {:error, error} -> {:error, error}
      error -> {:error, error}
    end
  end

  @spec leave_state(on_leave_callback() | nil, EXSM.State.user_state(), event() | nil) :: on_leave_result_mapped()
  def leave_state(on_leave, user_state, event \\ nil)

  def leave_state(nil, user_state, _), do: {:noreply, user_state}

  def leave_state(on_leave, user_state, event) do
    case on_leave.(user_state, event) do
      :ok -> {:noreply, user_state}
      {:noreply, new_user_state} -> {:noreply, new_user_state}
      {:error, error} -> {:error, error}
      error -> {:error, error}
    end
  end

  defp function_arity_0_or_2(function) do
    arity =
      :erlang.fun_info(function)
      |> Keyword.fetch!(:arity)

    arity == 0 or arity == 2
  end
end
