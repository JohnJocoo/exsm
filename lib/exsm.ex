defmodule EXSM do
  @moduledoc """
  Documentation for `EXSM`.
  """

  require Logger

  @type new_state_machine_opts :: [{:user_state, EXSM.State.user_state()} |
                                   {:initial_states, [EXSM.State.name()]} |
                                   {:regions, [atom()]}] |
                                  []
  @type replies :: [any()]
  @type ok_details :: [{:region, atom()}] | []
  @type error_details :: [{:rollback_error, any()} |
                          {:region, atom()} |
                          {:state_machine, EXSM.StateMachine.t()} |
                          {:reply, any()}
                         ] | []

  @spec states(module()) :: [EXSM.State.t()]
  def states(module) when is_atom(module) do
    module.__info__(:attributes)
    |> Keyword.get_values(:states)
    |> List.flatten()
  end

  @spec new(module(), new_state_machine_opts()) ::
          {:ok, EXSM.StateMachine.t()} | {:error, any()}
  def new(module, opts \\ []) when is_atom(module) do
    create(module, opts)
  end

  @spec process_event(module(), EXSM.StateMachine.t(), EXSM.Util.event()) ::
          {:ok, EXSM.StateMachine.t(), ok_details()} |
          {:ok, EXSM.StateMachine.t(), :no_transition | replies(), ok_details()} |
          {:error, :no_transition | any(), error_details()}
  def process_event(module, state_machine, event) when is_atom(module) do
    handle_event(module, state_machine, event)
  end

  @spec terminate(module(), EXSM.StateMachine.t()) ::
          :ok | {:error, [{EXSM.StateMachine.region(), any()}]}
  def terminate(module, state_machine) when is_atom(module) do
    leave_all(module, state_machine)
  end

  defp create(module, opts) do
    initial_states =
      get_initial_states(module, opts)
      |> Enum.map(fn %EXSM.State{name: name} = state ->
        case EXSM.Util.state_id_by_name(module, name) do
          {:ok, state_id} ->
            {state_id, state}

          {:error, :not_found} ->
            raise """
            Metadata for state #{inspect(name)} not found
            in module #{module}
            """
        end
      end)
    opts =
      if not Keyword.has_key?(opts, :regions) do
        [{:regions, get_regions(module)} | opts]
      else
        regions =
          get_regions(module)
          |> Map.new(fn %EXSM.Region{name: name} = region -> {name, region} end)
        filtered_regions =
          Keyword.get(opts, :regions, [])
          |> Enum.map(fn name ->
            case Map.get(regions, name) do
              nil ->
                raise """
                No region #{inspect(name)} exists
                in module #{module}
                """

              %EXSM.Region{} = region ->
                region
            end
          end)
        Keyword.replace!(opts, :regions, filtered_regions)
      end

    opts =
      if Keyword.has_key?(opts, :user_state) do
        opts
      else
        [{:user_state, get_default_user_state(module)} | opts]
      end

    opts = [{:default_transition_policy, get_default_transition_policy(module)} | opts]

    state_machine = EXSM.StateMachine.new(module, initial_states, opts)
    user_state = EXSM.StateMachine.user_state(state_machine)
    regions = EXSM.StateMachine.regions(state_machine)
    case enter_all_states(module, initial_states, user_state, regions) do
      {:ok, updated_states, updated_user_state} ->
        updated_state_machine =
          Enum.reduce(updated_states, state_machine,
            fn {state_id, %EXSM.State{region: region} = state}, state_machine ->
              EXSM.StateMachine.update_current_state(state_machine, {state_id, state}, region)
            end
          )
          |> EXSM.StateMachine.update_user_state(updated_user_state)
        {:ok, updated_state_machine}

      {:error, _} = error ->
        error
    end
  end

  defp get_regions(module) do
    module.__info__(:attributes)
    |> Keyword.get_values(:regions)
    |> List.flatten()
    |> then(fn
         [] -> [%EXSM.Region{name: nil}]
         regions when is_list(regions) -> regions
       end)
  end

  defp get_initial_states(module, opts) do
    case Keyword.get(opts, :initial_states) do
      nil ->
        initial_states =
          module.__info__(:attributes)
          |> Keyword.get_values(:initial_states)
          |> List.flatten()
        if initial_states == [] do
          raise """
          Initial state for SM should be provided in options to
          __MODULE__.new() if there is no initial state declared like:
          state :empty do
            initial true
          end
          """
        end
        initial_states

      initial_states_names when is_list(initial_states_names) and length(initial_states_names) > 0 ->
        names_set = MapSet.new(initial_states_names)
        initial_states =
          EXSM.states(module)
          |> Enum.filter(fn %EXSM.State{name: name} ->
            MapSet.member?(names_set, name)
          end)
        if initial_states == [] do
          raise ArgumentError, """
          No states #{inspect(initial_states_names)} exist
          for module #{module}
          """
        end
        states_not_found =
          MapSet.difference(
            names_set,
            MapSet.new(initial_states, &(&1.name))
          )
          |> MapSet.to_list()
        if states_not_found != [] do
          raise ArgumentError, """
          States #{inspect(states_not_found)} do not exist
          for module #{module}
          """
        end
        initial_states
    end
  end

  defp get_default_transition_policy(module) do
    [policy] =
      module.__info__(:attributes)
      |> Keyword.get(:default_transition_policy, [:reply])

    policy
  end

  defp enter_all_states(module, initial_states, user_state, regions) do
    region_state_ids =
      Map.new(initial_states, fn {id, %EXSM.State{region: region} = state} ->
        {region, {id, state}}
      end)
    Enum.map(regions, fn %EXSM.Region{name: region} -> region end)
    |> Enum.reduce_while({[], user_state}, fn region, {updated_states, acc_user_state} ->
      {state_id, state} = Map.fetch!(region_state_ids, region)
      try do
        case enter_state_or_sub(module, state_id, state, acc_user_state) do
          {:ok, state, updated_user_state} ->
            {:cont, {[{state_id, state} | updated_states], updated_user_state}}

          {:error, _} = error ->
            unroll_states(module, updated_states, acc_user_state, true)
            {:halt, error}
        end
      rescue
        e ->
          unroll_states(module, updated_states, acc_user_state, false)
          reraise e, __STACKTRACE__
      end
    end)
    |> then(fn
      {:error, _} = error ->
        error

      {updated_states, new_user_state} when is_list(updated_states) ->
        {:ok, updated_states, new_user_state}
    end)
  end

  defp unroll_states(module, states, user_state, do_reraise) do
    Enum.reduce_while(states, user_state, fn {state_id, state}, acc_user_state ->
      try do
        case leave_state_or_sub(module, state_id, state, acc_user_state) do
          {:ok, _state, new_user_state} ->
            {:cont, new_user_state}

          {:error, error} ->
            Logger.error """
            Error unrolling states occur #{inspect(error)},
            ignoring it as another error is about to be returned
            """
            {:halt, acc_user_state}
        end
      rescue
        exception ->
          if do_reraise do
            reraise exception, __STACKTRACE__
          else
            Logger.error Exception.format_banner(:error, exception)
          end
          {:halt, acc_user_state}
      end
    end)
  end

  defp handle_event(
         module,
         %EXSM.StateMachine{default_transition_policy: policy} = state_machine,
         event) do
    case {EXSM.StateMachine.terminal?(state_machine), policy} do
      {false, _} -> handle_event_active(module, state_machine, event)
      {true, :reply} -> {:ok, state_machine, :no_transition, []}
      {true, :ignore} -> {:ok, state_machine, []}
      {true, :error} -> {:error, :no_transition, [state_machine: state_machine]}
    end
  end

  defp handle_event_active(module, %EXSM.StateMachine{module: module} = state_machine, event) do
    original_user_state = EXSM.StateMachine.user_state(state_machine)
    state_machine
    |> EXSM.StateMachine.regions()
    |> Enum.map(fn %EXSM.Region{name: region_name} = region ->
        %EXSM.State{name: from_name} = from = EXSM.StateMachine.current_state(state_machine, region_name)
          case EXSM.Util.transition_info(module, from_name, event, original_user_state) do
            {:transition, {{^from_name, from_id}, to, action}} ->
              {:transition, region, {from, from_id}, to, action}

            {:no_transition, _} ->
              :no_transition
          end
       end)
    |> Enum.reject(&(&1 == :no_transition))
    |> Enum.reduce_while(
         {[], [], original_user_state},
         fn {:transition, %EXSM.Region{name: region_name} = region, from, to, action}, {results, details, user_state} ->
           transit_state(module, event, region, from, to, user_state, action)
         end
       )
  end

  # from == to is a config for internal transition
  # action is run without leaving old state and entering new one
  defp transit_state(_module, _event, region, {from, same_id}, {_, same_id}, user_state, action) do
    case EXSM.Util.handle_action(action, user_state) do
      {:noreply, updated_user_state} ->
        {:ok, from, updated_user_state, []}

      {:reply, reply, updated_user_state} ->
        {:ok, from, updated_user_state, reply, []}

      {:error, error} ->
        {:error, error, []}
    end
  end

  # leave from_state -> run action -> enter to_state
  # if error happens rollback will occur,
  # ex. leave from_state -> run action 💥 (error happened) -> enter from_state (rollback)
  defp transit_state(module, event, region, {from, from_id}, to, user_state, action) do
    case leave_state_or_sub(module, from_id, from, user_state, event) do
      {:ok, _updated_state, updated_user_state} ->
        run_action_and_enter(module, event, region, from, to, action, updated_user_state)

      {:error, error} ->
        {:error, error, []}
    end
  end

  defp run_action_and_enter(module, event, region, from, to, action, user_state) do
    case EXSM.Util.handle_action(action, user_state) do
      {:noreply, updated_user_state} ->
        case enter_state_normal(module, event, region, from, to, updated_user_state) do
          {:ok, new_state, updated_user_state} ->
            {:ok, new_state, updated_user_state, []}

          {:error, _, _} = error ->
            error
        end
      {:reply, reply, updated_user_state} ->
        case enter_state_normal(module, event, region, from, to, updated_user_state) do
          {:ok, new_state, updated_user_state} ->
            {:ok, new_state, updated_user_state, reply, []}

          {:error, error, details} ->
            {:error, error, [{:reply, reply} | details]}
        end
      {:error, error} ->
        case enter_state_rollback(module, event, region, from, user_state) do
          {:ok, new_state, updated_user_state} ->
            {:error, error, [{:state, new_state}, {:user_state, updated_user_state}]}

          {:error, rollback_error} ->
            {:error, error, [{:rollback_error, rollback_error}]}
        end
    end
  end

  defp enter_state_normal(module, event, region, from, {_, to_id}, user_state) do
    state = EXSM.Util.state_by_id(module, to_id)
    case enter_state_or_sub(module, to_id, state, user_state, event) do
      {:ok, new_state, updated_user_state} ->
        {:ok, new_state, updated_user_state}

      {:error, error} ->
        case enter_state_rollback(module, event, region, from, user_state) do
          {:ok, new_state, updated_user_state} ->
            {:error, error, [{:state, new_state}, {:user_state, updated_user_state}]}

          {:error, rollback_error} ->
            {:error, error, [{:rollback_error, rollback_error}]}
        end
    end
  end

  defp enter_state_rollback(module, _event, region, {_, state_id}, user_state) do
    state = EXSM.Util.state_by_id(module, state_id)
    case enter_state_or_sub(module, state_id, state, user_state) do
      {:ok, new_state, updated_user_state} ->
        {:ok, new_state, updated_user_state}

      {:error, _} = error ->
        error
    end
  end

  defp leave_all(module, %EXSM.StateMachine{module: module} = state_machine) do
    user_state = EXSM.StateMachine.user_state(state_machine)
    EXSM.StateMachine.regions(state_machine)
    |> Enum.reverse()
    |> Enum.reduce({user_state, []}, fn %EXSM.Region{name: region}, {user_state, acc} ->
      state_id = EXSM.StateMachine.current_state_id(state_machine, region)
      state = EXSM.StateMachine.current_state(state_machine, region)
      case leave_state_or_sub(module, state_id, state, user_state) do
        {:ok, _state, updated_user_state} ->
          {updated_user_state, acc}

        {:error, error} ->
          {user_state, [{region, error} | acc]}
      end
    end)
    |> then(fn {_, errors} -> errors end)
    |> then(fn
         [] -> :ok
         errors when is_list(errors) -> {:error, errors}
       end)
  end

  defp add_detail_not_nil(details, _key, nil), do: details
  defp add_detail_not_nil(details, key, value), do: [{key, value} | details]

  defp get_default_user_state(module) do
    [default_user_state] =
      module.__info__(:attributes)
      |> Keyword.get(:default_user_state, [nil])
    if is_function(default_user_state) do
      default_user_state.()
    else
      default_user_state
    end
  end

  defp enter_state_or_sub(module, id, state, user_state, event \\ nil)

  defp enter_state_or_sub(module, id, %EXSM.State{sub_state_machine?: false} = state, user_state, event) do
    on_enter = EXSM.Util.on_enter_by_id(module, id)
    case EXSM.Util.enter_state(on_enter, user_state, event) do
      {:noreply, updated_user_state} -> {:ok, state, updated_user_state}
      {:error, _} = error -> error
    end
  end

  defp enter_state_or_sub(module, id, %EXSM.State{sub_state_machine?: true} = state, user_state, event) do
    new_sub = EXSM.Util.sub_machine_new_by_id(module, id)
    case EXSM.Util.new_sub_machine(new_sub, user_state, event) do
      {:ok, state_machine, new_user_state} ->
        {:ok, %EXSM.State{state | _sub_state_machine: state_machine}, new_user_state}
      {:error, _} = error ->
        error
    end
  end

  defp leave_state_or_sub(module, id, state, user_state, event \\ nil)

  defp leave_state_or_sub(module, id, %EXSM.State{sub_state_machine?: false} = state, user_state, event) do
    on_leave = EXSM.Util.on_leave_by_id(module, id)
    case EXSM.Util.leave_state(on_leave, user_state, event) do
      {:noreply, updated_user_state} -> {:ok, state, updated_user_state}
      {:error, _} = error -> error
    end
  end

  defp leave_state_or_sub(
         module,
         id,
         %EXSM.State{sub_state_machine?: true, _sub_state_machine: sub_machine} = state,
         user_state,
         event
       ) when sub_machine != nil do
    terminate_sub = EXSM.Util.sub_machine_terminate_by_id(module, id)
    case EXSM.Util.terminate_sub_machine(terminate_sub, sub_machine, user_state, event) do
      {:ok, new_user_state} ->
        {:ok, %EXSM.State{state | _sub_state_machine: nil}, new_user_state}
      {:error, _} = error ->
        error
    end
  end
end
