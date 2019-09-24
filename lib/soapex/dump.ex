defmodule Soapex.Dump do
  @moduledoc false

  @enable Application.get_env(:soapex, __MODULE__)[:enabled]
  @path Application.get_env(:soapex, __MODULE__)[:path]

  defp dump_to_file() do
    
  end
end