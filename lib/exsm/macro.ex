defmodule EXSM.Macro do
  @moduledoc false

  alias EXSM.Macro
  alias EXSM.State

  defstruct [:state, :on_enter, :on_leave]

  def from_keyword(name, keyword) do
    %Macro{
      state: %State{
        name: name,
        description: Keyword.get(keyword, :description),
        initial?: Keyword.get(keyword, :initial?, false)
      },
      on_enter: Keyword.get(keyword, :on_enter),
      on_leave: Keyword.get(keyword, :on_leave)
    }
  end

  def assert_in_block(module, attribute, block_name, current_scope) do
    if not Module.has_attribute?(module, attribute) do
      raise """
      #{current_scope} can only be defined within #{block_name} block"
      Example:
      #{block_name} do
        #{current_scope} ...
      end
      """
    end
  end
end
