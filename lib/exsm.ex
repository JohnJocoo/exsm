defmodule EXSM do
  @moduledoc """
  Documentation for `EXSM`.
  """

  require Logger

  @type new_state_machine_opts :: [{:user_state, EXSM.State.user_state()} |
                                   {:initial_states, [EXSM.State.name()]} |
                                   {:regions, [atom()]}] |
                                  []
  @type reply :: any()
  @type ok_details :: [{:region, atom()}] | []
  @type error_details :: [{:rollback_error, any()} |
                          {:region, atom()} |
                          {:state_machine, EXSM.StateMachine.t()} |
                          {:reply, reply()}
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
          {:ok, EXSM.StateMachine.t(), :no_transition | reply(), ok_details()} |
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

    state_machine = EXSM.StateMachine.new(module, initial_states, opts)
    user_state = EXSM.StateMachine.user_state(state_machine)
    regions = EXSM.StateMachine.regions(state_machine)
    case enter_all_states(module, initial_states, user_state, regions) do
      {:ok, updated_user_state} ->
        {:ok, EXSM.StateMachine.update_user_state(state_machine, updated_user_state)}

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

  defp enter_all_states(module, initial_states, user_state, regions) do
    region_state_ids =
      Map.new(initial_states, fn {id, %EXSM.State{region: region}} ->
        {region, id}
      end)
    Enum.map(regions, fn %EXSM.Region{name: region} -> region end)
    |> Enum.reduce_while({[], user_state}, fn region, {entered_states, acc_user_state} ->
      state_id = Map.fetch!(region_state_ids, region)
      try do
        on_enter = EXSM.Util.on_enter_by_id(module, state_id)
        case EXSM.Util.enter_state(on_enter, acc_user_state) do
          {:noreply, updated_user_state} ->
            {:cont, {[state_id | entered_states], updated_user_state}}

          {:error, _} = error ->
            unroll_states(module, entered_states, acc_user_state, true)
            {:halt, error}
        end
      rescue
        e ->
          unroll_states(module, entered_states, acc_user_state, false)
          reraise e, __STACKTRACE__
      end
    end)
    |> then(fn
      {:error, _} = error ->
        error

      {ids, new_user_state} when is_list(ids) ->
        {:ok, new_user_state}
    end)
  end

  defp unroll_states(module, state_ids, user_state, do_reraise) do
    Enum.reduce_while(state_ids, user_state, fn state_id, acc_user_state ->
      try do
        on_leave = EXSM.Util.on_leave_by_id(module, state_id)
        case EXSM.Util.leave_state(on_leave, acc_user_state) do
          {:noreply, new_user_state} ->
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

  defp handle_event(module, %EXSM.StateMachine{module: module} = state_machine, event) do
    case find_transition_info(module, state_machine, event) do
      {:transition, region, {from, to, action}} ->
        transit_state(module, state_machine, event, region, from, to, action)

      {:no_transition, :ignore} ->
        {:ok, state_machine, []}

      {:no_transition, :reply} ->
        {:ok, state_machine, :no_transition, []}

      {:no_transition, :error} ->
        {:error, :no_transition, [state_machine: state_machine]}
    end
  end

  defp find_transition_info(module, state_machine, event) do
    user_state = EXSM.StateMachine.user_state(state_machine)
    EXSM.StateMachine.regions(state_machine)
    |> Enum.reduce_while(nil, fn %EXSM.Region{name: region}, _ ->
      %EXSM.State{name: from} = EXSM.StateMachine.current_state(state_machine, region)
      case EXSM.Util.transition_info(module, from, event, user_state) do
        {:transition, transition} ->
          {:halt, {:transition, region, transition}}

        {:no_transition, _} = no_transition ->
          {:cont, no_transition}
      end
    end)
  end

  # from == to is a config for internal transition
  # action is run without leaving old state and entering new one
  defp transit_state(_module, state_machine, _event, region, same_state, same_state, action) do
    user_state = EXSM.StateMachine.user_state(state_machine)
    case EXSM.Util.handle_action(action, user_state) do
      {:noreply, updated_user_state} ->
        updated_state_machine = EXSM.StateMachine.update_user_state(state_machine, updated_user_state)
        {:ok, updated_state_machine, add_detail_not_nil([], :region, region)}

      {:reply, reply, updated_user_state} ->
        updated_state_machine = EXSM.StateMachine.update_user_state(state_machine, updated_user_state)
        {:ok, updated_state_machine, reply, add_detail_not_nil([], :region, region)}

      {:error, error} ->
        {:error, error, add_detail_not_nil([state_machine: state_machine], :region, region)}
    end
  end

  # leave from_state -> run action -> enter to_state
  # if error happens rollback will occur,
  # ex. leave from_state -> run action 💥 (error happened) -> enter from_state (rollback)
  defp transit_state(module, state_machine, event, region, {_, from_id} = from, to, action) do
    user_state = EXSM.StateMachine.user_state(state_machine)
    on_leave = EXSM.Util.on_leave_by_id(module, from_id)
    case EXSM.Util.leave_state(on_leave, user_state, event) do
      {:noreply, updated_user_state} ->
        run_action_and_enter(module, state_machine, event, region, from, to, action, updated_user_state)

      {:error, error} ->
        {:error, error, add_detail_not_nil([state_machine: state_machine], :region, region)}
    end
  end

  defp run_action_and_enter(module, state_machine, event, region, from, to, action, user_state) do
    case EXSM.Util.handle_action(action, user_state) do
      {:noreply, updated_user_state} ->
        case enter_state_normal(module, state_machine, event, region, from, to, updated_user_state) do
          {:ok, state_machine} ->
            {:ok, state_machine, add_detail_not_nil([], :region, region)}

          {:error, _, _} = error ->
            error
        end
      {:reply, reply, updated_user_state} ->
        case enter_state_normal(module, state_machine, event, region, from, to, updated_user_state) do
          {:ok, state_machine} ->
            {:ok, state_machine, reply, add_detail_not_nil([], :region, region)}

          {:error, error, details} ->
            {:error, error, [{:reply, reply} | details]}
        end
      {:error, error} ->
        case enter_state_rollback(module, state_machine, event, region, from, user_state) do
          {:ok, state_machine} ->
            {:error, error, add_detail_not_nil([state_machine: state_machine], :region, region)}

          {:error, rollback_error} ->
            {:error, error, add_detail_not_nil([rollback_error: rollback_error], :region, region)}
        end
    end
  end

  defp enter_state_normal(module, state_machine, event, region, from, {_, to_id}, user_state) do
    on_enter = EXSM.Util.on_enter_by_id(module, to_id)
    case EXSM.Util.enter_state(on_enter, user_state, event) do
      {:noreply, updated_user_state} ->
        new_state = EXSM.Util.state_by_id(module, to_id)
        update_state_machine =
          state_machine
          |> EXSM.StateMachine.update_user_state(updated_user_state)
          |> EXSM.StateMachine.update_current_state({to_id, new_state}, region)
        {:ok, update_state_machine}

      {:error, error} ->
        case enter_state_rollback(module, state_machine, event, region, from, user_state) do
          {:ok, state_machine} ->
            {:error, error, add_detail_not_nil([state_machine: state_machine], :region, region)}

          {:error, rollback_error} ->
            {:error, error, add_detail_not_nil([rollback_error: rollback_error], :region, region)}
        end
    end
  end

  defp enter_state_rollback(module, state_machine, _event, region, {_, state_id}, user_state) do
    on_enter = EXSM.Util.on_enter_by_id(module, state_id)
    case EXSM.Util.enter_state(on_enter, user_state, nil) do
      {:noreply, updated_user_state} ->
        new_state = EXSM.Util.state_by_id(module, state_id)
        update_state_machine =
          state_machine
          |> EXSM.StateMachine.update_user_state(updated_user_state)
          |> EXSM.StateMachine.update_current_state({state_id, new_state}, region)
        {:ok, update_state_machine}

      {:error, _} = error ->
        error
    end
  end

  defp leave_all(module, %EXSM.StateMachine{module: module} = state_machine) do
    user_state = EXSM.StateMachine.user_state(state_machine)
    EXSM.StateMachine.regions(state_machine)
    |> Enum.reverse()
    |> Enum.reduce({user_state, []}, fn %EXSM.Region{name: region}, {user_state, acc} ->
      on_leave = EXSM.Util.on_leave_by_id(module, EXSM.StateMachine.current_state_id(state_machine, region))
      case EXSM.Util.leave_state(on_leave, user_state) do
        {:noreply, updated_user_state} ->
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
end
