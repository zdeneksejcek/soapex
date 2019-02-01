defmodule Soapex.Wsdl do
  @moduledoc false

  import SweetXml
  import Soapex.Util
  alias Soapex.Fetcher

  @spec get_wsdl(string()) :: map()
  def get_wsdl(path) do
    # get content of all related files (wsdl + schemas)
    case Fetcher.get_files(path) do
      {:ok, files} ->
        parse_files(files)
      {:error, message} ->
        {:error, message}
    end
  end

  @spec parse_files(map()) :: map()
  def parse_files(files) do
    nss = %{
      wsdl:    get_schema_prefix(files.wsdl, "http://schemas.xmlsoap.org/wsdl/"),
      schema:  get_schema_prefix(files.wsdl, "http://www.w3.org/2001/XMLSchema"),
      http:    get_schema_prefix(files.wsdl, "http://schemas.xmlsoap.org/wsdl/http/"),
      soap10:  get_schema_prefix(files.wsdl, "http://schemas.xmlsoap.org/wsdl/soap/"),
      soap12:  get_schema_prefix(files.wsdl, "http://schemas.xmlsoap.org/wsdl/soap12/")
    }

    %{
      services:   get_services(files.wsdl, nss),
      bindings:   get_bindings(files.wsdl, nss),
      port_types: get_port_types(files.wsdl, nss),
      messages:   get_messages(files.wsdl, nss)
    }
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
    message
    |> xpath(~x"//#{ns("part", nss.wsdl)}"l, name: ~x"./@name"s, element: ~x"./@element"s, type: ~x"./@type"s)
    |> Enum.map(&no_nil_or_empty_value/1)
  end

  defp get_bindings(wsdl, nss) do
    wsdl
    |> xpath(~x"//#{ns("binding", nss.wsdl)}"l, name: ~x"./@name"s, type: ~x"./@type"s)
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

            trans = [nss.http, nss.soap10, nss.soap12]
                    |> Enum.map(fn ns -> xpath(p, ~x"./#{ns("address", ns)}/@location"s) |> to_nil end)

            port = case trans do
                      [http, nil, nil]    -> %{protocol: :http, location: http}
                      [nil, soap10, nil]  -> %{protocol: :soap10, location: soap10}
                      [nil, nil, soap12] -> %{protocol: :soap12, location: soap12}
                   end

            Map.merge(port, %{binding: binding})
         end)
  end
end