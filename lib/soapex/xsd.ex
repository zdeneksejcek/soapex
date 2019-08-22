defmodule Soapex.Xsd do
  @moduledoc false

  import SweetXml
  import Soapex.Util

  @spec get_schema(String.t()) :: map
  def get_schema(schema) do
    if schema == nil, do: throw("Schema is nil")

    get_schema_internal(schema)
  end

  defp get_schema_internal(schema_el) do
    %{
      target_ns: schema_el |> ns_xpath(~x"@targetNamespace"so),
      attribute_form_default: get_qualified_unqualified(schema_el, "attributeFormDefault"),
      element_form_default: get_qualified_unqualified(schema_el, "elementFormDefault"),
      elements: get_elements(schema_el),
      complex_types: get_complex_types(schema_el),
      simple_types: get_simple_types(schema_el),
      attribute_groups: get_attribute_groups(schema_el)
    }
  end

  defp get_qualified_unqualified(schema_el, att_name) do
    case schema_el |> ns_xpath(~x"@#{att_name}"so) do
      "" ->
        :unqualified

      nil ->
        :unqualified

      "unqualified" ->
        :unqualified

      "qualified" ->
        :qualified
    end
  end

  defp get_simple_types(schema_el) do
    schema_el
    |> ns_xpath(~x"./xsd:simpleType"l)
    |> map_simple_types
    |> Enum.map(&no_nil_or_empty_value/1)
  end

  defp get_simple_type(node) do
    name =
      node
      |> ns_xpath(~x".",
        name: ~x"./@name"s,
        restriction: ~x"." |> transform_by(&get_restriction/1),
        union: ~x"." |> transform_by(&get_union/1)
      )

    name
    |> no_nil_or_empty_value
  end

  defp get_union(node) do
    node
    |> ns_xpath(~x"./xsd:union"oe,
      member_types: ~x"@memberTypes",
      simple_types: ~x"./xsd:simpleType"l |> transform_by(&map_simple_types/1)
    )
    |> no_nil_or_empty_value
  end

  defp map_simple_types(simple_type_els) do
    simple_type_els
    |> Enum.map(&get_simple_type/1)
  end

  defp get_restriction(node) do
    restriction =
      node
      |> ns_xpath(~x"./xsd:restriction"oe,
        base: ~x"./@base"s,
        length: ~x"./xsd:length/@value"s,
        min_length: ~x"./xsd:minLength/@value"s,
        max_length: ~x"./xsd:maxLength/@value"s,
        min_exclusive: ~x"./xsd:minExclusive/@value"s,
        max_exclusive: ~x"./xsd:maxExclusive/@value"s,
        min_inclusive: ~x"./xsd:minInclusive/@value"s,
        max_inclusive: ~x"./xsd:maxInclusive/@value"s,
        total_digits: ~x"./xsd:totalDigits/@value"s,
        fraction_digits: ~x"./xsd:fractionDigits/@value"s,
        enumeration: ~x"./xsd:enumeration"l,
        white_space: ~x"./xsd:whiteSpace/@value"s,
        pattern: ~x"./xsd:pattern/@value"s
      )
      |> no_nil_or_empty_value

    case restriction do
      nil ->
        nil

      _ ->
        restriction
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

  defp get_attribute_groups(parent) do
    parent
    |> ns_xpath(~x"./xsd:attributeGroup"l)
    |> map_attribute_group
  end

  defp map_attribute_group(group_els) do
    group_els
    |> Enum.map(&get_attribute_group/1)
  end

  defp get_attribute_group(group_el) do
    name =
      group_el
      |> ns_xpath(~x".",
        name: ~x"./@name"os,
        ref: ~x"./@ref"os,
        any_attribute: ~x"./xsd:anyAttribute"oe
      )

    name
    |> no_nil_or_empty_value
  end

  #  defp get_any_attribute(nil), do: nil
  #  defp get_any_attribute(any_att_el) do
  #    any_att_el
  #    |>
  #  end

  @spec get_complex_types(String.t()) :: list(Map.t())
  defp get_complex_types(schema_el) do
    schema_el
    |> ns_xpath(~x"./xsd:complexType"l)
    |> Enum.map(fn node -> get_complex_type(node) end)
  end

  defp get_complex_type(nil), do: nil

  defp get_complex_type(node) do
    name = node |> ns_xpath(~x".", name: ~x"./@name"s)

    elements =
      node
      |> ns_xpath(~x"./xsd:sequence | ./xsd:choice | ./xsd:all")
      |> get_element_list

    type =
      case node |> ns_xpath(~x"./xsd:sequence | ./xsd:choice | ./xsd:all") do
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
      nil ->
        nil

      _ ->
        parent
        |> ns_xpath(~x"./xsd:element"l)
        |> Enum.map(fn node -> get_element(node) end)
    end
  end

  @spec get_elements(String.t()) :: list(Map.t())
  defp get_elements(schema_el) do
    schema_el
    |> ns_xpath(~x"./xsd:element"l)
    |> Enum.map(fn node -> get_element(node) end)
  end

  defp get_element(node) do
    header =
      node
      |> ns_xpath(~x".",
        name: ~x"./@name"s,
        ref: ~x"./@ref"s |> transform_by(&type/1),
        type: ~x"./@type"s |> transform_by(&type/1),
        nillable: ~x"./@nillable"os |> transform_by(&boolean/1),
        min_occurs: ~x"./@minOccurs"oi,
        max_occurs: ~x"./@maxOccurs"os,
        complex_type: ~x".//xsd:complexType"oe |> transform_by(&get_complex_type/1)
      )

    header
    |> no_nil_or_empty_value
  end

  defp boolean(""), do: nil
  defp boolean(nil), do: nil
  defp boolean("false"), do: false
  defp boolean("true"), do: true
end
