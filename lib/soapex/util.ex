defmodule Soapex.Util do
  @moduledoc false

  import SweetXml

  @spec get_schema_prefix(String.t(), String.t()) :: String.t()
  def get_schema_prefix(schema, uri) do
    schema
    |> xpath(~x"//namespace::*"l)
    |> Enum.find(fn {_, _, _, _, url} -> url == String.to_atom(uri) end)
    |> no_nil(fn value -> elem(value, 3) end)
  end

  @spec get_soap_version(String.t()) :: {:ok, any()} | {:error, string()}
  def get_soap_version(schema) do
    soap10 = get_schema_prefix(schema, "http://schemas.xmlsoap.org/wsdl/soap/")
    soap12 = get_schema_prefix(schema, "http://schemas.xmlsoap.org/wsdl/soap12/")

  end

  def ns(name, []), do: "#{name}"
  def ns(name, namespace), do: "#{namespace}:#{name}"

  def to_nil(""), do: nil
  def to_nil(va), do: va

  def ensure_list(value) do
    case value do
      nil -> []
      _ -> value
    end
  end

  def remove_ns(type) when is_binary(type) do
    case String.split(type, ":", trim: true) do
      [ns, name] -> name
      [name] -> name
    end
  end

  def no_nil_or_empty_value(map) do
    map
    |> Enum.reject(fn({_, v}) -> v == nil || v == [] || v == "" end)
    |> Enum.into(%{})
  end

  def no_nil(value, func) do
    case value do
      nil -> nil
      _ -> func.(value)
    end
  end
end
