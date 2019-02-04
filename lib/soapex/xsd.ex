defmodule Soapex.Xsd do
  @moduledoc false

  import SweetXml
  import Soapex.Util

  @spec get_types(String.t(), map) :: map
  def get_types(schema, nss) do
    schema_el = schema |> xpath(~x"//#{ns("schema", nss.schema)}")

    get_schema(schema_el, nss.schema)
  end

  def get_schema(schema_el, schema_ns) do
    %{
      xsd_prefix:     List.to_string(schema_ns),
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
    restriction = node |> xpath(~x"./#{ns("restriction", schema_ns)}", base: ~x"./@base"s)

    enumerations = node
                   |> xpath(~x"./#{ns("restriction", schema_ns)}/#{ns("enumeration", schema_ns)}"l)
                   |> ensure_list
                   |> Enum.map(fn node -> xpath(node, ~x"./@value"s) end)

    name
    |> Map.merge(%{
        restriction: restriction,
        enumerations: enumerations
    })
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
    header =        node |> xpath(~x".", name: ~x"./@name"s, type: ~x"./@type"s)
    complex_type =  node |> xpath(~x"./#{ns("complexType", schema_ns)}") |> get_complex_type(schema_ns)

    Map.merge(header, %{
      complex_type: complex_type
    }) |> no_nil_or_empty_value
  end

end