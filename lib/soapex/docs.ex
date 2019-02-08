defmodule Soapex.Docs do
  @moduledoc false

  def operation(op) do
    faults = op.faults
             |> Enum.map(fn f -> "- {:#{Macro.underscore(f.name)}, fault_details}" end)
             |> Enum.join(" ")

    "Faults: #{faults}"
  end

end
