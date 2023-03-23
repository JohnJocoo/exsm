defmodule PSSM.Transition019Test do
  use PSSM

  defmodule S1 do
    use EXSM.SMAL

    region :R1 do
      state "S1.1" do
        initial true
        on_leave do: PSSM.log_leave("S1.1")
      end
      state "S1.2" do
        terminal true
        on_leave do: PSSM.log_leave("S1.2")
      end
    end

    region :R2 do
      state "S2.1" do
        initial true
        on_leave do: PSSM.log_leave("S2.1")
      end
      state "S2.2" do
        terminal true
        on_leave do: PSSM.log_leave("S2.2")
      end
    end

    transitions do
      "S1.1" <- :continue >>> "S1.2"
        action do: PSSM.log_action("T1.2")
      "S2.1" <- :continue >>> "S2.2"
        action do: PSSM.log_action("T1.2")
    end
  end

  test_pssm state_machine: S1,
            events: [:continue],
            expected_log: [
              {:leave, "S1.1"},
              {:action, "T1.2"},
              {:leave, "S2.1"},
              {:action, "T2.2"},
              {:leave, "S1.2"},
              {:leave, "S2.2"}
            ]
end
