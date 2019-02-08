defmodule Soapex.Xsd do
  @moduledoc false

  import SweetXml
  import Soapex.Util

  def get_types(schema) do
    nss = get_namespaces(schema)

    schema_el = schema |> xpath(~x"//#{ns("schema", nss.schema)}")

    get_schema(schema_el, nss.schema)
  end

  @spec get_types(String.t(), map) :: map
  def get_types(schema, nss) do
    schema_el = schema |> xpath(~x"//#{ns("schema", nss.schema)}")

    get_schema(schema_el, nss.schema)
  end

  def get_schema(schema_el, schema_ns) do
    %{
      xsd_prefix:     schema_ns,
      elements:       get_elements(schema_el, schema_ns),
      complex_types:  get_complex_types(schema_el, schema_ns),
      simple_types:   get_simple_types(schema_el, schema_ns)
    }
  end

  @spec get_simple_types(String.t(), String.t()) :: list(Map.t())
  defp get_simple_types(schema_el, schema_ns) do
    schema_el
    |> xpath(~x"./#{ns("simpleType", schema_ns)}"l)
    |> Enum.map(fn node -> get_simple_type(node, schema_ns) end)
    |> Enum.map(&no_nil_or_empty_value/1)
  end

  defp get_simple_type(node, schema_ns) do
    name = node |> xpath(~x".", name: ~x"./@name"s)
    restriction = node |> get_restriction(schema_ns)

    name
    |> Map.merge(%{restriction: restriction})
    |> no_nil_or_empty_value
  end

  defp get_restriction(node, schema_ns) do
    restriction = node |> xpath(~x"./#{ns("restriction", schema_ns)}"o,
          base:           ~x"./@base"s,
          length:         ~x"./#{ns("length", schema_ns)}/@value"s,
          min_length:     ~x"./#{ns("minLength", schema_ns)}/@value"s,
          max_length:     ~x"./#{ns("maxLength", schema_ns)}/@value"s,
          min_exclusive:  ~x"./#{ns("minExclusive", schema_ns)}/@value"s,
          max_exclusive:  ~x"./#{ns("maxExclusive", schema_ns)}/@value"s,
          min_inclusive:  ~x"./#{ns("minInclusive", schema_ns)}/@value"s,
          max_inclusive:  ~x"./#{ns("maxInclusive", schema_ns)}/@value"s,
          total_digits:   ~x"./#{ns("totalDigits", schema_ns)}/@value"s,
          fraction_digits: ~x"./#{ns("fractionDigits", schema_ns)}/@value"s,
          enumeration:    ~x"./#{ns("enumeration", schema_ns)}"l,
          white_space:    ~x"./#{ns("whiteSpace", schema_ns)}/@value"s,
          pattern:        ~x"./#{ns("pattern", schema_ns)}/@value"s)
      |> no_nil_or_empty_value

    case restriction do
      nil ->  nil
      _ ->    restriction
              |> Map.put(:enumeration, get_enumeration(restriction[:enumeration]))
              |> Map.put(:base, type(restriction[:base], schema_ns))
              |> no_nil_or_empty_value
    end
  end

  defp get_enumeration(nil), do: nil
  defp get_enumeration(enums) do
    enums
    |> ensure_list
    |> Enum.map(fn node -> xpath(node, ~x"./@value"s) end)
  end

  @spec get_complex_types(String.t(), String.t()) :: list(Map.t())
  defp get_complex_types(schema_el, schema_ns) do
    schema_el
    |> xpath(~x"./#{ns("complexType", schema_ns)}"l)
    |> Enum.map(fn node -> get_complex_type(node, schema_ns) end)
  end

  defp get_complex_type(nil, _), do: nil

  defp get_complex_type(node, schema_ns) do
    name = node |> xpath(~x".", name: ~x"./@name"s)
    elements = node
                |> xpath(~x"./#{ns("sequence", schema_ns)} | ./#{ns("choice", schema_ns)} | ./#{ns("all", schema_ns)}")
                |> get_element_list(schema_ns)

    type = case node |> xpath(~x"./#{ns("sequence", schema_ns)} | ./#{ns("choice", schema_ns)} | ./#{ns("all", schema_ns)}") do
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

  defp get_element_list(parent, schema_ns) do
    case parent do
      nil -> nil
      _ -> parent
           |> xpath(~x"./#{ns("element", schema_ns)}"l)
           |> Enum.map(fn node -> get_element(node, schema_ns) end)
    end
  end

  @spec get_elements(String.t(), String.t()) :: list(Map.t())
  defp get_elements(schema_el, schema_ns) do
    schema_el
    |> xpath(~x"./#{ns("element", schema_ns)}"l)
    |> Enum.map(fn node -> get_element(node, schema_ns) end)
  end

  defp get_element(node, schema_ns) do
    header =        node |> xpath(~x".", name: ~x"./@name"s, type: ~x"./@type"s, nillable: ~x"./@nillable"os, min_occurs: ~x"./@minOccurs"oi, max_occurs: ~x"./@maxOccurs"os)
    complex_type =  node |> xpath(~x"./#{ns("complexType", schema_ns)}") |> get_complex_type(schema_ns)

    header
    |> Map.put(:nillable, boolean(header[:nillable]))
    |> Map.put(:type, type(header[:type], schema_ns))
    |> Map.merge(%{complex_type: complex_type})
    |> no_nil_or_empty_value
  end

  defp boolean(""), do: nil
  defp boolean(nil), do: nil
  defp boolean("false"), do: false
  defp boolean("true"), do: true
end