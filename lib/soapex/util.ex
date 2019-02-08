defmodule Soapex.Util do
  @moduledoc false

  import SweetXml

  @spec get_schema_prefix(String.t(), String.t()) :: String.t()
  def get_schema_prefix(namespaces, uri) do
    namespaces
    |> Enum.find(fn {_, _, _, _, url} -> url == String.to_atom(uri) end)
    |> no_nil(fn value -> elem(value, 3) end)
    |> no_nil(&List.to_string/1)
  end

  def get_namespaces(root) do
    namespaces = root |> xpath(~x"//namespace::*"l)

    %{
      wsdl:    get_schema_prefix(namespaces, "http://schemas.xmlsoap.org/wsdl/"),
      schema:  get_schema_prefix(namespaces, "http://www.w3.org/2001/XMLSchema"),
      soap11:  get_schema_prefix(namespaces, "http://schemas.xmlsoap.org/wsdl/soap/"),
      soap12:  get_schema_prefix(namespaces, "http://schemas.xmlsoap.org/wsdl/soap12/")
    }
  end

  def ns(name, ""), do: "#{name}"
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

  def no_nil_or_empty_value(nil), do: nil

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
