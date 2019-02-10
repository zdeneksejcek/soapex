defmodule Soapex.Xsd do
  @moduledoc false

  import SweetXml
  import Soapex.Util

  def get_types(schema) do
    # nss = get_namespaces(schema)
    schema_el = schema |> ns_xpath(~x"//xsd:schema")

    get_schema(schema_el)
  end

  @spec get_types(String.t()) :: map
  def get_types(schema) do
    if schema == nil, do: throw "Schema is nil"

    schema_el = schema |> ns_xpath(~x"//xsd:schema"oe)

    get_schema(schema_el)
  end

  def get_schema(schema_el) do
    %{
      elements:       get_elements(schema_el),
      complex_types:  get_complex_types(schema_el),
      simple_types:   get_simple_types(schema_el)
    }
  end

  defp get_simple_types(schema_el) do
    schema_el
    |> ns_xpath(~x"./xsd:simpleType"l)
    |> Enum.map(fn node -> get_simple_type(node) end)
    |> Enum.map(&no_nil_or_empty_value/1)
  end

  defp get_simple_type(node) do
    name = node |> ns_xpath(~x".", name: ~x"./@name"s)
    restriction = node |> get_restriction

    name
    |> Map.merge(%{restriction: restriction})
    |> no_nil_or_empty_value
  end

  defp get_restriction(node) do
    restriction = node |> ns_xpath(~x"./xsd:restriction"o,
          base:           ~x"./@base"s,
          length:         ~x"./xsd:length/@value"s,
          min_length:     ~x"./xsd:minLength/@value"s,
          max_length:     ~x"./xsd:maxLength/@value"s,
          min_exclusive:  ~x"./xsd:minExclusive/@value"s,
          max_exclusive:  ~x"./xsd:maxExclusive/@value"s,
          min_inclusive:  ~x"./xsd:minInclusive/@value"s,
          max_inclusive:  ~x"./xsd:maxInclusive/@value"s,
          total_digits:   ~x"./xsd:totalDigits/@value"s,
          fraction_digits: ~x"./xsd:fractionDigits/@value"s,
          enumeration:    ~x"./xsd:enumeration"l,
          white_space:    ~x"./xsd:whiteSpace/@value"s,
          pattern:        ~x"./xsd:pattern/@value"s)
      |> no_nil_or_empty_value

    case restriction do
      nil ->  nil
      _ ->    restriction
              |> Map.put(:enumeration, get_enumeration(restriction[:enumeration]))
              |> Map.put(:base, type(restriction[:base]))
              |> no_nil_or_empty_value
    end
  end

  defp get_enumeration(nil), do: nil
  defp get_enumeration(enums) do
    enums
    |> ensure_list
    |> Enum.map(fn node -> ns_xpath(node, ~x"./@value"s) end)
  end

  @spec get_complex_types(String.t()) :: list(Map.t())
  defp get_complex_types(schema_el) do
    schema_el
    |> ns_xpath(~x"./xsd:complexType"l)
    |> Enum.map(fn node -> get_complex_type(node) end)
  end

  defp get_complex_type(nil), do: nil

  defp get_complex_type(node) do
    name = node |> ns_xpath(~x".", name: ~x"./@name"s)
    elements = node
                |> ns_xpath(~x"./xsd:sequence | ./xsd:choice | ./xsd:all")
                |> get_element_list

    type = case node |> ns_xpath(~x"./xsd:sequence | ./xsd:choice | ./xsd:all") do
            nil -> :empty
            el -> get_element_name(el)
           end
    name
    |> Map.merge(%{elements: elements, type: type})
    |> no_nil_or_empty_value
  end

  defp get_element_name(el) do
    {_, _, _, {_, name}, _, _, _, _, _, _, _, _} = el

    :erlang.list_to_atom(name)
  end

  defp get_element_list(parent) do
    case parent do
      nil -> nil
      _ -> parent
           |> ns_xpath(~x"./xsd:element"l)
           |> Enum.map(fn node -> get_element(node) end)
    end
  end

  @spec get_elements(String.t()) :: list(Map.t())
  defp get_elements(schema_el) do
    schema_el
    |> xpath(~x"./xsd:element"l)
    |> Enum.map(fn node -> get_element(node) end)
  end

  defp get_element(node) do
    header =        node |> ns_xpath(~x".", name: ~x"./@name"s, type: ~x"./@type"s, nillable: ~x"./@nillable"os, min_occurs: ~x"./@minOccurs"oi, max_occurs: ~x"./@maxOccurs"os)
    complex_type =  node |> ns_xpath(~x"./xsd:complexType") |> get_complex_type

    header
    |> Map.put(:nillable, boolean(header[:nillable]))
    |> Map.put(:type, type(header[:type]))
    |> Map.merge(%{complex_type: complex_type})
    |> no_nil_or_empty_value
  end

  defp boolean(""), do: nil
  defp boolean(nil), do: nil
  defp boolean("false"), do: false
  defp boolean("true"), do: true
end