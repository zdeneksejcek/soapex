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
      services:   get_services(files.wsdl, files.nss),
      bindings:   get_bindings(files.wsdl, files.nss),
      port_types: get_port_types(files.wsdl, files.nss),
      messages:   get_messages(files.wsdl, files.nss),
      types:      get_types(files.wsdl, files.imports, files.nss)
    }
  end

  defp get_types(wsdl, imports, nss) do
    local_type = wsdl
                 |> xpath(~x"//#{ns("definitions", nss.wsdl)}/#{ns("types", nss.wsdl)}/#{ns("schema", nss.schema)}")
                 |> Xsd.get_types(nss)

    imported_types = imports
                     |> Enum.map(fn im -> Xsd.get_types(im.content) end)

    %{
      simple_types:   join_lists(local_type, imported_types, :simple_types),
      complex_types:  join_lists(local_type, imported_types, :complex_types),
      elements:       join_lists(local_type, imported_types, :elements),
    }
  end

  defp join_lists(local_type, imported_types, name) do
    local_type[name] ++ Enum.reduce(imported_types, [], fn v, acc -> v[name] ++ acc end)
  end

  defp get_messages(wsdl, nss) do
    wsdl
    |> xpath(~x"//#{ns("message", nss.wsdl)}"l)
    |> Enum.map(fn p -> %{
            name: xpath(p, ~x"./@name"s),
            parts: get_message_parts(p, nss)
          } end)
  end

  defp get_message_parts(message, nss) do
    parts = message
            |> xpath(~x"//#{ns("part", nss.wsdl)}"l, name: ~x"./@name"s, element: ~x"./@element"s, type: ~x"./@type"s)

    parts
    |> Enum.map(fn p ->
          Map.put(p, :type, type(p[:type],        nss.schema))
          |> Map.put(:element, type(p[:element],  nss.schema))
       end)
    |> Enum.map(&no_nil_or_empty_value/1)
  end

  defp get_bindings(wsdl, nss) do
    wsdl
    |> xpath(~x"//#{ns("binding", nss.wsdl)}"l)
    |> Enum.map(fn p -> get_binding(p, nss) end)
    |> Enum.reject(fn x -> x[:soap] == nil end)
  end

  defp get_binding(bin_el, nss) do
    binding =           bin_el |> xpath(~x".", name: ~x"./@name"s, type: ~x"./@type"s)
    soap =              bin_el |> xpath(~x"./#{ns("binding", nss.soap11)} | ./#{ns("binding", nss.soap12)}"o, style: ~x"./@style"s, transport: ~x"./@transport"s)

    operations = bin_el
                 |> xpath(~x"./#{ns("operation", nss.wsdl)}"l)
                 |> Enum.map(fn p -> get_binding_operation(p, nss) end)

    Map.merge(binding, %{
      operations: operations,
      soap:       soap
    })
  end

  defp get_binding_operation(op_el, nss) do
    operation =         op_el |> xpath(~x".", name: ~x"./@name"s)
    soap =              op_el |> xpath(~x"./#{ns("operation", nss.soap11)} | ./#{ns("operation", nss.soap12)}"o, style: ~x"./@style"s, soap_action: ~x"./@soapAction"s)

    input =             get_operation_body(op_el, nss, "input")
    output =            get_operation_body(op_el, nss, "output")

    input_header =      get_operation_header(op_el, nss, "input")
    output_header =     get_operation_header(op_el, nss, "output")

    Map.merge(operation, %{
      soap:   soap,
      input:  input,
      input_header: input_header,
      output_header: output_header,
      output: output,
      faults: get_binding_faults(op_el, nss)
    }) |> no_nil_or_empty_value
  end

  defp get_operation_body(op_el, nss, type) do
    op_el
    |> xpath(~x"./#{ns(type, nss.wsdl)}/#{ns("body", nss.soap11)} | ./#{ns(type, nss.wsdl)}/#{ns("body", nss.soap12)}"o, namespace: ~x"./@namespace"s, use: ~x"./@use"s)
  end

  defp get_operation_header(op_el, nss, type) do
    op_el
    |> xpath(~x"./#{ns(type, nss.wsdl)}/#{ns("header", nss.soap11)} | ./#{ns(type, nss.wsdl)}/#{ns("header", nss.soap12)}"o, part: ~x"./@part"s, message: ~x"./@message"s, use: ~x"./@use"s)
  end

  defp get_binding_faults(op_el, nss) do
    op_el
    |> xpath(~x"./#{ns("fault", nss.wsdl)}"l)
    |> Enum.map(fn f_el ->
        xpath(f_el, ~x".", name: ~x"./@name"s, use: ~x"./#{ns("fault", nss.soap11)}/@use | ./#{ns("fault", nss.soap12)}/@use"s)
    end)
  end

  defp get_port_types(wsdl, nss) do
     wsdl
     |> xpath(~x"//#{ns("portType", nss.wsdl)}"l)
     |> Enum.map(fn p -> %{
            name: xpath(p, ~x"./@name"s),
            operations: get_port_type_operations(p, nss)
        }
        end)
  end

  defp get_port_type_operations(port_type, nss) do
    port_type
    |> xpath(~x"./#{ns("operation", nss.wsdl)}"l)
    |> Enum.map(fn node ->
      name = node |> xpath(~x"@name"s)
      input_message = node |> xpath(~x"#{ns("input", nss.wsdl)}/@message"s)
      output_message = node |> xpath(~x"#{ns("output", nss.wsdl)}/@message"s)

      faults = node |> xpath(~x"#{ns("fault", nss.wsdl)}"l)
                    |> Enum.map(fn fault_node ->
                          fault_node |> xpath(~x".", message: ~x"./@message"s, name: ~x"./@name"s)
                       end)

      {name, %{input_message: input_message, output_message: output_message, faults: faults}}
    end)
    |> Map.new
  end

  defp get_services(wsdl, nss) do
    wsdl
    |> xpath(~x"//#{ns("definitions", nss.wsdl)}/#{ns("service", nss.wsdl)}"l)
    |> Enum.map(fn srv -> get_service(srv, nss) end)
  end

  defp get_service(srv_el, nss) do
    name =  srv_el |> xpath(~x"./@name"s)
    ports = get_service_ports(srv_el, nss)

    %{
      name:   name, # TODO
      ports:  ports
    }
  end

  defp get_service_ports(srv_el, nss) do
    srv_el
    |> xpath(~x"./#{ns("port", nss.wsdl)}"l)
    |> Enum.map(
         fn p ->
            binding = remove_ns(xpath(p, ~x"./@binding"s))
            name = xpath(p, ~x"./@name"s)

            trans = [nss.soap11, nss.soap12]
                    |> Enum.map(fn ns -> xpath(p, ~x"./#{ns("address", ns)}/@location"s) |> to_nil end)

            port = case trans do
                      [nil, nil] -> %{protocol: :unknown}
                      [soap11, nil]  -> %{protocol: :soap11, location: soap11}
                      [nil, soap12] -> %{protocol: :soap12, location: soap12}
                   end

            Map.merge(port, %{binding: binding, name: name})
         end)
      |> Enum.reject(fn p -> p.protocol == :unknown end)
  end
end