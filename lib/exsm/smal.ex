defmodule EXSM.SMAL do
  @moduledoc """
  Documentation for `EXSM.SMAL`.
  """

  # opts:
  #   no_transition: :reply | :ignore | :error | :no_function_match
  #   default_user_state: term() | ( -> term())
  defmacro __using__(opts) do
    default_transition_values = [:no_function_match, :ignore, :reply, :error]
    default_transition_policy = Keyword.get(opts, :no_transition, :reply)

    if default_transition_policy not in default_transition_values do
      raise """
      :default_transition can only be one of #{inspect(default_transition_values)}
      """
    end

    default_user_state = Keyword.get(opts, :default_user_state, nil)

    quote do
      import EXSM.Macro
      import unquote(__MODULE__)

      @before_compile EXSM.Macro

      Module.register_attribute(__MODULE__, :states, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :states_meta, accumulate: true)
      Module.register_attribute(__MODULE__, :initial_states, accumulate: true, persist: true)
      Module.register_attribute(__MODULE__, :default_transition_policy, persist: true)
      Module.put_attribute(__MODULE__, :default_transition_policy, unquote(default_transition_policy))
      Module.put_attribute(__MODULE__, :states_meta_defined, false)
      Module.register_attribute(__MODULE__, :regions, accumulate: true, persist: true)

      default_user_state = unquote(default_user_state)
      if is_function(default_user_state) and 0 != :erlang.fun_info(default_user_state) |> Keyword.fetch!(:arity) do
        raise """
          :default_user_state for EXSM state machine can only be
          constant value or function/0
        """
      end

      Module.register_attribute(__MODULE__, :default_user_state, persist: true)
      Module.put_attribute(__MODULE__, :default_user_state, default_user_state)
    end
  end

  ### Transition table definition macros

  defmacro state_from <- expression do
    state_from_ast = Macro.escape(state_from)

    expression_keyword = EXSM.Macro.transition_to_keyword(expression)
    expression_ast = Macro.escape(expression_keyword)

    state_to = Keyword.fetch!(expression_keyword, :to)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "operator <-")

      states = Module.get_attribute(EXSM.Util.parent_module(__MODULE__), :states_meta)
      EXSM.Macro.assert_state_exists(unquote(state_from), states)
      EXSM.Macro.assert_state_exists(unquote(state_to), states)

      EXSM.Macro._inject_transition()

      Module.register_attribute(__MODULE__, :current_transition_keyword, accumulate: true)
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:from, unquote(state_from_ast)})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:from_value, unquote(state_from)})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:to_value, unquote(state_to)})
      Enum.each(unquote(expression_ast), fn {key, value} ->
        Module.put_attribute(__MODULE__, :current_transition_keyword, {key, value})
      end)
    end
  end

  defmacro action([user_state: _] = opts, do: expression), do: EXSM.SMAL._action(opts, do: expression)

  defmacro action(do: expression), do: EXSM.SMAL._action([], do: expression)

  defmacro action(function) do
    function_ast = Macro.escape(function)

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "action")

      action = EXSM.Util.function_to_arity_2(unquote(function), unquote(function_ast))
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action, true})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action_function, action})
    end
  end

  def _action(opts, do: expression) do
    EXSM.Util.assert_only_allowed_keywords(opts, [:user_state], "action")
    EXSM.Macro.assert_action_variables(expression)
    expression_ast = Macro.escape(expression)
    user_state_ast =
      Keyword.get(opts, :user_state, {:_, [], nil})
      |> Macro.escape()

    quote do
      EXSM.Macro.assert_in_block(__MODULE__, :transitions, "transitions", "action")

      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action, true})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action_block, unquote(expression_ast)})
      Module.put_attribute(__MODULE__, :current_transition_keyword, {:action_user_state, unquote(user_state_ast)})
    end
  end
end
