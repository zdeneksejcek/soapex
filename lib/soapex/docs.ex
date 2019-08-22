defmodule Soapex.Docs do
  @moduledoc false

  def faults(op) do
    faults =
      op.faults
      |> Enum.map(fn f -> "- *#{Macro.underscore(f.name)}*" end)
      |> Enum.join(" \n")

    faults
  end

  def parameters(op) do
    op.input_message.parts
    |> Enum.map(fn f -> "- *#{Macro.underscore(f.name)}* #{get_type(f)}" end)
    |> Enum.join(" \n")
  end

  defp get_type(part) do
    # name, type, element

    case part[:type] do
      type when is_atom(type) ->
        type

      _ ->
        ""
    end
  end
end
