defmodule Soapex.Wsdl do
  @moduledoc false

  # rpc vs document
  # https://www.ibm.com/support/knowledgecenter/en/SSB27H_6.2.0/fa2ws_ovw_soap_syntax_lit.html
  # https://www.ibm.com/developerworks/library/ws-usagewsdl/index.html

  import SweetXml
  import Soapex.Util
  alias Soapex.Fetcher
  alias Soapex.Xsd

  @spec get_wsdl(String.t()) :: map()
  def get_wsdl(path) do
    case Fetcher.get_files(path) do
      {:ok, files} ->
        parse_files(files)

      {:error, message} ->
        {:error, message}
    end
  end

  @spec parse_files(map()) :: map()
  def parse_files(files) do
    %{
      services: get_services(files.wsdl),
      bindings: get_bindings(files.wsdl),
      port_types: get_port_types(files.wsdl),
      messages: get_messages(files.wsdl),
      schemes: get_schemes(files.wsdl, files.imports)
      # nss: get_wsdl_namespaces(files.wsdl)
    }
  end

  def get_schemes(wsdl, imports) do
    local_schema =
      wsdl
      |> ns_xpath(~x"//wsdl:definitions/wsdl:types/xsd:schema")
      |> Xsd.get_schema()

    imported_schemas =
      imports
      |> Enum.map(fn im -> Xsd.get_schema(im.content) end)

    [local_schema | imported_schemas]
    |> remove_empty_schemas
  end

  defp remove_empty_schemas(schemas) do
    schemas
  end

  defp get_messages(wsdl) do
    wsdl
    |> ns_xpath(~x"//wsdl:message"l)
    |> Enum.map(fn p ->
      %{
        name: ns_xpath(p, ~x"./@name"s),
        parts: get_message_parts(p)
      }
    end)
  end

  defp get_element_namespaces(nss) do
    nss
    |> Enum.map(fn {:xmlNsNode, _, _, short, uri} ->
      {"#{short}", "#{uri}"}
    end)
    |> Enum.into(%{})
  end

  defp get_message_parts(message) do
    parts =
      message
      |> ns_xpath(~x"//wsdl:part"l,
        name: ~x"./@name"s,
        element: ~x"./@element"s |> transform_by(&type/1),
        element_uri: ~x"./@element"s |> transform_by(&get_ns/1),
        type: ~x"./@type"s |> transform_by(&type/1),
        type_uri: ~x"./@type"s |> transform_by(&get_ns/1),
        nss: ~x"./namespace::*"l |> transform_by(&get_element_namespaces/1)
      )

    parts
    |> Enum.map(fn part ->
      Map.put(part, :element_uri, part[:nss][part[:element_uri]])
      |> Map.put(:type_uri, part[:nss][part[:type_uri]])
      |> Map.delete(:nss)
    end)
    |> Enum.map(&no_nil_or_empty_value/1)
  end

  defp get_bindings(wsdl) do
    wsdl
    |> ns_xpath(~x"//wsdl:binding"l)
    |> Enum.map(fn p -> get_binding(p) end)
    |> Enum.reject(fn x -> x[:soap] == nil end)
  end

  defp get_binding(bin_el) do
    binding = bin_el |> ns_xpath(~x".", name: ~x"./@name"s, type: ~x"./@type"s)

    soap =
      bin_el
      |> ns_xpath(~x"./soap11:binding | ./soap12:binding"o,
        style: ~x"./@style"s,
        transport: ~x"./@transport"s
      )

    operations =
      bin_el
      |> ns_xpath(~x"./wsdl:operation"l)
      |> Enum.map(fn p -> get_binding_operation(p) end)

    # Update style, from operations directly if needed
    soap =
      case soap[:style] do
        "" ->
          style =
            case Enum.at(operations, 0) do
              nil -> nil
              op -> op[:style]
            end

          Map.put(soap, :style, style)

        val ->
          Map.put(soap, :style, get_style(soap[:style]))
      end

    Map.merge(binding, %{
      operations: operations,
      soap: soap
    })
  end

  defp update_style(nil), do: nil

  defp update_style(map) do
    Map.put(map, :style, get_style(map[:style]))
  end

  defp get_style(nil), do: nil
  defp get_style(""), do: nil
  defp get_style("rpc"), do: :rpc
  defp get_style("document"), do: :document

  defp get_binding_operation(op_el) do
    operation = op_el |> ns_xpath(~x".", name: ~x"./@name"s)

    soap_action =
      op_el |> ns_xpath(~x"./soap11:operation/@soapAction | ./soap12:operation/@soapAction"os)

    style = op_el |> ns_xpath(~x"./soap11:operation/@style | ./soap12:operation/@style"os)

    input = get_operation_body(op_el, "input")
    output = get_operation_body(op_el, "output")

    input_header = get_operation_header(op_el, "input")
    output_header = get_operation_header(op_el, "output")

    Map.merge(operation, %{
      style: get_style(style),
      soap_action: soap_action,
      input: input,
      input_header: input_header,
      output_header: output_header,
      output: output,
      faults: get_binding_faults(op_el)
    })
    |> no_nil_or_empty_value
  end

  defp get_operation_body(op_el, type) do
    op_el
    |> ns_xpath(~x"./wsdl:#{type}/soap11:body | ./wsdl:#{type}/soap12:body"o,
      namespace: ~x"./@namespace"os |> transform_by(&to_nil/1),
      use: ~x"./@use"s |> transform_by(&to_nil/1)
    )
  end

  defp get_operation_header(op_el, type) do
    op_el
    |> ns_xpath(~x"./wsdl:#{type}/soap11:header | ./wsdl:#{type}/soap12:header"o,
      part: ~x"./@part"s,
      message: ~x"./@message"s,
      use: ~x"./@use"s
    )
  end

  defp get_binding_faults(op_el) do
    op_el
    |> ns_xpath(~x"./wsdl:fault"l)
    |> Enum.map(fn f_el ->
      ns_xpath(f_el, ~x".",
        name: ~x"./@name"s,
        use: ~x"./soap11:fault/@use | ./soap12:fault/@use"s
      )
    end)
  end

  defp get_port_types(wsdl) do
    wsdl
    |> ns_xpath(~x"//wsdl:portType"l)
    |> Enum.map(fn p ->
      %{
        name: ns_xpath(p, ~x"./@name"s),
        operations: get_port_type_operations(p)
      }
    end)
  end

  defp get_port_type_operations(port_type) do
    port_type
    |> ns_xpath(~x"./wsdl:operation"l)
    |> Enum.map(fn node ->
      name = node |> ns_xpath(~x"@name"s)
      input_message = node |> ns_xpath(~x"wsdl:input/@message"s)
      output_message = node |> ns_xpath(~x"wsdl:output/@message"s)

      faults =
        node
        |> ns_xpath(~x"wsdl:fault"l)
        |> Enum.map(fn fault_node ->
          fault_node |> ns_xpath(~x".", message: ~x"./@message"s, name: ~x"./@name"s)
        end)

      {name, %{input_message: input_message, output_message: output_message, faults: faults}}
    end)
    |> Map.new()
  end

  defp get_services(wsdl) do
    wsdl
    |> ns_xpath(~x"//wsdl:definitions/wsdl:service"l)
    |> Enum.map(fn srv -> get_service(srv) end)
  end

  defp get_service(srv_el) do
    name = srv_el |> ns_xpath(~x"./@name"s)
    ports = get_service_ports(srv_el)

    %{
      # TODO
      name: name,
      ports: ports
    }
  end

  defp get_service_ports(srv_el) do
    srv_el
    |> ns_xpath(~x"./wsdl:port"l)
    |> Enum.map(fn p ->
      binding = remove_ns(ns_xpath(p, ~x"./@binding"s))
      name = ns_xpath(p, ~x"./@name"s)

      location_11 = p |> ns_xpath(~x"./soap11:address/@location"s) |> to_nil
      location_12 = p |> ns_xpath(~x"./soap12:address/@location"s) |> to_nil

      %{
        binding: binding,
        name: name,
        protocol:
          case {location_11, location_12} do
            {nil, nil} -> :uknown
            {nil, _} -> :soap12
            {_, nil} -> :soap11
          end,
        location:
          case location_11 do
            nil -> location_12
            _ -> location_11
          end
      }
    end)
    |> Enum.reject(fn p -> p.protocol == :uknown end)
  end
end
