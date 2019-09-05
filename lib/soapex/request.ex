defmodule Soapex.Request do
  @moduledoc false

  import XmlBuilder
  import SweetXml
  import Soapex.Util

  require Logger

  def create_request(t_wsdl, wsdl, port_path, operation_name, parameters) do
    data = get_operation(t_wsdl, port_path, operation_name)

    body = create_body(data.operation, parameters, wsdl.schemes)
    envelope = create_envelope(data, body)
    headers = get_headers(data)

    # {envelope, headers}
    Logger.debug("Request body: #{inspect(envelope)}")

    post(data.url, envelope, headers, data)
  end

  defp get_operation(t_wsdl, {service, port}, operation) do
    service = t_wsdl[service]
    port = service[port]

    %{
      url: port.location,
      operation: port.operations[operation],
      protocol: port.protocol
    }
  end

  defp get_headers(data) do
    action_header =
      case data.operation.soap_action do
        nil ->
          []

        soap_action ->
          [SOAPaction: soap_action]
      end

    content_type =
      case data.protocol do
        :soap11 -> ["Content-Type": "text/xml; charset=\"utf-8\""]
        :soap12 -> ["Content-Type": "application/soap+xml; charset=\"utf-8\""]
      end

    action_header ++ content_type
  end

  defp create_envelope(data, body) do
    env_ns_url =
      case data.protocol do
        :soap11 -> "http://schemas.xmlsoap.org/soap/envelope/"
        :soap12 -> "http://www.w3.org/2003/05/soap-envelop"
      end

    _doc =
      element(
        "env:Envelope",
        %{"xmlns:env" => env_ns_url, "xmlns:s" => data.operation.input_message_ns} |> no_nil_or_empty_value,
        [
          element("env:Body", [
            body
          ])
        ]
      )
      |> XmlBuilder.generate(format: :none)
  end

  defp create_body(op, parameters, schemes) do
    case op.soap_style do
      :document ->
        create_body_document(op, parameters, schemes)

      :rpc ->
        create_body_rpc(op, parameters, schemes)
    end
  end

  defp create_body_rpc(op, parameters, _schemes) do
    element(op.name, [
      op.input_message.parts
      |> Enum.map(fn p -> create_body_element(p.name, parameters[p.name]) end)
    ])
  end

  defp create_body_element(param_name, param_value) when is_list(param_value) do
    elements =
      param_value
      |> Enum.map(fn {name, value} -> create_body_element(name, value) end)

    element(param_name, nil, elements)
  end

  defp create_body_element(param_name, param_value) when is_map(param_value) do
    element(
      param_name,
      nil,
      param_value
      |> Enum.map(fn p ->
        {name, value} = p
        create_body_element(name, value)
      end)
    )
  end

  defp create_body_element(param_name, param_value) do
    element(param_name, param_value)
  end

  defp create_body_document(op, parameters, _schemas) do
    parts = op.input_message.parts
    case parts do
      [part] ->
        element(
          "operation:#{part[:element]}",
          %{"xmlns:operation" => part[:element_uri]},
          [parameters["parameters"]
           |> Enum.map(fn {key, value} -> create_body_element(key, value) end)]
        )
      _ ->
        throw("Only one message part is supported at the time for document style")
    end
  end

  defp post(url, body, headers, data) do
    case HTTPoison.post(url, body, headers,
           follow_redirect: true,
           max_redirect: 3,
           timeout: 10_000,
           recv_timeout: 20_000
         ) do
      {:ok, %HTTPoison.Response{status_code: status_code} = response} when status_code == 200 ->
        Logger.debug("Response (200) body: #{inspect(response.body)}")
        {:ok, parse_success(response, data)}

      {:ok, %HTTPoison.Response{status_code: status_code} = response} when status_code >= 400 ->
        Logger.error("Response body (> 400): #{inspect(response.body)}")
        fault = parse_fault(response, data)
        {:fault, fault.name, fault.fault}

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        {:error, :timeout}

      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_success(response, data) do
    nss = get_response_nss(response, data)

    body_el =
      response.body |> xpath(~x"//#{ns("Envelope", nss.env_ns)}/#{ns("Body", nss.env_ns)}/*[1]"e)

    %{
      body: element_to_data(body_el, nss)
    }
  end

  def element_to_data(body_el, nss) do
    el_name = body_el |> xpath(~x"local-name(.)"os)

    children =
      body_el
      |> xpath(~x"./*"l)
      |> Enum.map(fn el -> element_to_data(el, nss) end)

    value = body_el |> xpath(~x"./text()"s)

    is_nil = body_el |> xpath(~x"./@#{ns("nil", nss.schema_ns)}"os) == "true"

    {el_name, get_element_value(children, value, is_nil)}
  end

  defp get_element_value(children, value, is_nil) do
    case {children, value, is_nil} do
      {[], "", true} ->
        nil

      {[], "", false} ->
        ""

      {[], _, _} ->
        value

      {_, _, _} ->
        children
    end
  end

  defp parse_fault(response, data) do
    case get_response_nss(response, data) do
      %{env11_ns: env11_ns, env12_ns: nil} ->
        parse_fault_soap11(env11_ns, response.body)

      %{env11_ns: nil, env12_ns: env12_ns} ->
        parse_fault_soap12(env12_ns, response.body)
    end
  end

  defp get_response_nss(response, data) do
    namespaces = response.body |> xpath(~x"//namespace::*"l)

    nss = %{
      env11_ns: get_schema_prefix(namespaces, "http://schemas.xmlsoap.org/soap/envelope/"),
      env12_ns: get_schema_prefix(namespaces, "http://www.w3.org/2003/05/soap-envelop"),
      schema_ns: get_schema_prefix(namespaces, "http://www.w3.org/2001/XMLSchema-instance")
    }

    env_ns =
      case nss.env11_ns do
        nil -> nss.env12_ns

        _ -> nss.env11_ns
      end

    Map.put_new(nss, :env_ns, env_ns)
  end

  defp parse_fault_soap11(env_ns, response) do
    fault =
      response
      |> xpath(~x"//#{ns("Envelope", env_ns)}/#{ns("Body", env_ns)}/#{ns("Fault", env_ns)}"e,
        code: ~x"./faultcode/text()"s,
        string: ~x"./faultstring/text()"s,
        actor: ~x"./faultactor/text()"s,
        detail: ~x"./detail/*[1]"e,
        fault: ~x"local-name(./detail/*[1])"s,
      )
      |> append_specific_detail_soap11()

    %{
      name: String.to_atom(Macro.underscore(fault.fault)),
      fault: fault
    }
  end

  defp append_specific_detail_soap11(map) do
    detail = map[:detail]

    Map.put_new(map, :specific, nil)
  end

  defp parse_fault_soap12(_env_ns, _response) do
    throw("soap_12 fault parsing not available yet")
  end
end