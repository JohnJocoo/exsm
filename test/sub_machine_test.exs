defmodule EXSM.SubMachineTest do
  use ExUnit.Case, async: true

  alias EXSM.State
  alias EXSM.StateMachine

  defmodule SimpleSubMachine do
    use EXSM.SMAL
    use EXSM.Functions, [:new, :terminate]

    state :one, do: initial true
    state :two
    state :three, do: terminal true

    transitions do
      :one <- :increment >>> :two
      :two <- :increment >>> :three
    end
  end

  defmodule SimpleMachine do
    use EXSM.SMAL, default_user_state: %{token: "ab12"}

    state :initial do
      initial true
    end

    state :final do
      terminal true
    end

    state SimpleSubMachine do
      sub_machine true
      init_opts [user_state: %{data: "hello"}]
    end

    state :sub_machine_custom do
      sub_machine true
      module SimpleSubMachine
      new [user_state: %{token: token}, event: event] do
        SimpleSubMachine.new(initial_states: [:two], user_state: %{token: token, event: event})
      end
      terminate [state_machine: state_machine] do
        SimpleSubMachine.terminate(state_machine)
      end
    end

    transitions do
      :initial <- :to_sub_machine >>> SimpleSubMachine
      :initial <- :to_custom_sub_machine >>> :sub_machine_custom
      SimpleSubMachine <- :finish >>> :final
      :sub_machine_custom <- :increment >>> :final
    end
  end

end
