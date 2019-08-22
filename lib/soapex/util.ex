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
      wsdl: get_schema_prefix(namespaces, "http://schemas.xmlsoap.org/wsdl/"),
      schema: get_schema_prefix(namespaces, "http://www.w3.org/2001/XMLSchema"),
      soap11: get_schema_prefix(namespaces, "http://schemas.xmlsoap.org/wsdl/soap/"),
      soap12: get_schema_prefix(namespaces, "http://schemas.xmlsoap.org/wsdl/soap12/")
    }
  end

  def ns_xpath(parent, query) do
    xpath(parent, query |> add_nss)
  end

  def ns_xpath(parent, query, subspec) do
    xpath(parent, query |> add_nss, subspec |> add_nss_subspec)
  end

  defp add_nss_subspec(subspec) do
    subspec
    |> Enum.map(fn {key, value} ->
      {key, value |> add_nss}
    end)
  end

  def add_nss(query) do
    query
    |> add_namespace("wsdl", "http://schemas.xmlsoap.org/wsdl/")
    |> add_namespace("xsd", "http://www.w3.org/2001/XMLSchema")
    |> add_namespace("soap11", "http://schemas.xmlsoap.org/wsdl/soap/")
    |> add_namespace("soap12", "http://schemas.xmlsoap.org/wsdl/soap12/")
  end

  def ns(name, nil), do: "#{name}"
  def ns(name, ""), do: "#{name}"
  def ns(name, []), do: "#{name}"
  def ns(name, namespace), do: "#{namespace}:#{name}"

  def to_nil(%{}), do: nil
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
      [_ns, name] -> name
      [name] -> name
    end
  end

  def no_nil_or_empty_value(nil), do: nil

  def no_nil_or_empty_value(map) do
    map
    |> Enum.reject(fn {_, v} -> v == nil || v == [] || v == "" end)
    |> Enum.into(%{})
  end

  def no_nil(value, func) do
    case value do
      nil -> nil
      _ -> func.(value)
    end
  end

  # https://www.w3.org/2001/XMLSchema-datatypes
  def type(""), do: nil
  def type(nil), do: nil

  def type(value) do
    case String.split(value, ":") do
      [_, b_type] ->
        case b_type do
          "string" ->
            :string

          "boolean" ->
            :boolean

          "float" ->
            :float

          "double" ->
            :double

          "decimal" ->
            :decimal

          "dateTime" ->
            :date_time

          "duration" ->
            :duration

          "hexBinary" ->
            :hex_binary

          "base64Binary" ->
            :base64_binary

          "anyURI" ->
            :any_uri

          "ID" ->
            :id

          "IDREF" ->
            :id_ref

          "ENTITY" ->
            :entity

          "NOTATION" ->
            :notation

          "normalizedString" ->
            :normalized_string

          "token" ->
            :token

          "language" ->
            :language

          "nonNegativeInteger" ->
            :non_negative_integer

          "positiveInteger" ->
            :positive_integer

          "nonPositiveInteger" ->
            :non_positive_integer

          "negativeInteger" ->
            :negative_integer

          "byte" ->
            :byte

          "int" ->
            :int

          "long" ->
            :long

          "short" ->
            :short

          "unsignedByte" ->
            :unsigned_byte

          "unsignedInt" ->
            :unsigned_int

          "unsignedLong" ->
            :unsigned_long

          "unsignedShort" ->
            :unsigned_short

          "date" ->
            :date

          "time" ->
            :time

          "gYearMonth" ->
            :g_year_month

          "gYear" ->
            :g_year

          "gMonthDay" ->
            :g_month_day

          "gDay" ->
            :g_day

          "gMonth" ->
            :g_month

          dt ->
            dt
        end

      [custom_type] ->
        custom_type
    end
  end
end
