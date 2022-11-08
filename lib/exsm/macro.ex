defmodule EXSM.Macro do
  @moduledoc false

  alias EXSM.Macro

  defmodule State do
    defstruct [:state, :on_enter, :on_leave]
  end

  def state_from_keyword(name, keyword) do
    has_duplicate_keys =
      Enum.group_by(keyword, &elem(&1, 0), &elem(&1, 1))
      |> Enum.any?(fn {_, elements} -> length(elements) > 1 end)

    if has_duplicate_keys do
      raise """
      state #{name} has duplicate attributes
      #{inspect(Enum.map(keyword, &elem(&1, 0)))}
      """
    end

    %Macro.State{
      state: %EXSM.State{
        name: name,
        description: Keyword.get(keyword, :description),
        initial?: Keyword.get(keyword, :initial?, false)
      },
      on_enter: Keyword.get(keyword, :on_enter),
      on_leave: Keyword.get(keyword, :on_leave)
    }
  end

  def transition_right_expression_to_keyword(expression, state_from) do
    []
  end

  def transition_ast_from_keyword(nil) do
    quote do
    end
  end

  def transition_ast_from_keyword([]) do
    quote do
    end
  end

  def transition_ast_from_keyword(keyword) do
    quote do
    end
  end

  def assert_in_block(module, attribute, block_name, current_function) do
    if not Module.has_attribute?(module, attribute) do
      raise """
      #{current_function} can only be defined within #{block_name} block"
      Example:
      #{block_name} do
        #{current_function} ...
      end
      """
    end
  end
end
