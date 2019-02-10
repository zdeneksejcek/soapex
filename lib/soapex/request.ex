defmodule Soapex.Request do
  @moduledoc false

  import XmlBuilder
  import SweetXml
  import Soapex.Util

  def create_request(t_wsdl, wsdl, port_path, operation_name, parameters) do
    data = get_operation(t_wsdl, port_path, operation_name)

    body = create_body(data.operation, parameters, wsdl.types)
    envelope = create_envelope(data, body)
    _headers = get_headers(data)

    envelope

    # post(data.url, envelope, headers, data)
  end

  defp get_operation(t_wsdl, {service, port}, operation) do
    service = t_wsdl
              |> Enum.find(fn ser -> ser.name == service end)

    port = service.ports |> Enum.find(fn p -> p.name == port end)

    %{
      url:        port.location,
      operation:  port.operations |> Enum.find(fn o -> o.name == operation end),
      protocol:   port.protocol
    }
  end

  defp get_headers(data) do
    action_header = case data.operation.soap_action do
                      nil ->
                        []
                      soap_action ->
                        ["SOAPaction": soap_action]
                    end

    content_type = case data.protocol do
                    :soap11 -> ["Content-Type": "text/xml; charset=\"utf-8\""]
                    :soap12 -> ["Content-Type": "application/soap+xml; charset=\"utf-8\""]
                   end

    action_header ++ content_type
  end

  defp create_envelope(data, body) do
    env_ns_url = case data.protocol do
                  :soap11 -> "http://schemas.xmlsoap.org/soap/envelope/"
                  :soap12 -> "http://www.w3.org/2003/05/soap-envelop"
                 end

    _doc = element("env:Envelope", %{"xmlns:env" => env_ns_url, "xmlns:s" => data.operation.input_message_ns}, [
            element("env:Body", [
              body
            ])
          ]) |> XmlBuilder.generate(format: :none)
  end

  defp create_body(op, parameters, types) do
    case op.soap_style do
      :document ->
        create_body_document(op, parameters, types)
      :rpc ->
        create_body_rpc(op, parameters, types)
    end
  end

  defp create_body_rpc(op, parameters, _types) do
    element(op.name, [
      op.input_message.parts |> Enum.map(fn p -> element(p.name, parameters[p.name]) end)
    ])
  end

  defp create_body_document(op, parameters, types) do
    parts = op.input_message.parts

    case parts do
      [part] ->
        {_ns, element_name} = part.element
        root_element = types.elements |> Enum.find(&(&1.name == element_name))
      _ ->
        throw "Only one message part is supported at the time for document style"
    end
  end

  defp post(url, body, headers, data) do
    case HTTPoison.post(url, body, headers, follow_redirect: true, max_redirect: 3) do
      {:ok,  %HTTPoison.Response{status_code: status_code} = response} when status_code == 200 ->
        {:ok, parse_success(response, data)}
      {:ok, %HTTPoison.Response{status_code: status_code} = response} when status_code >= 400 ->
        fault = parse_fault(response, data)
        {:fault, fault.name, fault.fault}
      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_success(response, data) do
    nss = get_response_nss(response, data)
    body_el = response.body |> xpath(~x"//#{ns("Envelope", nss.env_ns)}/#{ns("Body", nss.env_ns)}/*[1]"e)

    %{
      body: element_to_data(body_el, nss)
    }
  end

  def element_to_data(body_el, nss) do
    el_name = body_el |> xpath(~x"local-name(.)"os)
    children = body_el
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
      %{env11_ns: env11_ns, env12_ns: nil, op_ns: op_ns} ->
        parse_fault_soap11(env11_ns, response.body, op_ns)
      %{env11_ns: nil, env12_ns: env12_ns, op_ns: op_ns} ->
        parse_fault_soap12(env12_ns, response.body, op_ns)
    end
  end

  defp get_response_nss(response, data) do
    namespaces = response.body |> xpath(~x"//namespace::*"l)
    nss = %{
      env11_ns:   get_schema_prefix(namespaces, "http://schemas.xmlsoap.org/soap/envelope/"),
      env12_ns:   get_schema_prefix(namespaces, "http://www.w3.org/2003/05/soap-envelop"),
      schema_ns:  get_schema_prefix(namespaces, "http://www.w3.org/2001/XMLSchema-instance"),
      op_ns:      get_schema_prefix(namespaces, data.operation.output_message_ns)
    }
    env_ns = case nss.env11_ns do
                nil -> nss.env12_ns
                _ ->  nss.env11_ns
             end

    Map.put_new(nss, :env_ns, env_ns)
  end

  defp parse_fault_soap11(env_ns, response, op_ns) do
    fault = response |> xpath(~x"//#{ns("Envelope", env_ns)}/#{ns("Body", env_ns)}/#{ns("Fault", env_ns)}"e,
                    code:   ~x"./faultcode/text()"s,
                    string: ~x"./faultstring/text()"s,
                    actor:  ~x"./faultactor/text()"s,
                    detail: ~x"./detail/*[1]"e,
                    fault:  ~x"local-name(./detail/*[1])"s)
    %{
      name:   String.to_atom(Macro.underscore(fault.fault)),
      fault:  fault
    }
  end

  defp parse_fault_soap12(_env_ns, _response, _op_ns) do
    throw "soap_12 fault parsing not available yet"
  end
end

#<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:blz="http://thomas-bayer.com/blz/">
#   <soap:Header/>
#   <soap:Body>
#      <blz:getBank>
#         <blz:blz>50010517</blz:blz>
#      </blz:getBank>
#   </soap:Body>
#</soap:Envelope>

#<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://www.zasilkovna.cz/api/soap.wsdl">
#   <SOAP-ENV:Body>
#      <SOAP-ENV:Fault>
#         <faultcode>SOAP-ENV:Client</faultcode>
#         <faultstring>Incorrect API password.</faultstring>
#         <faultactor>http://www.zasilkovna.cz/api/soap</faultactor>
#         <detail>
#            <ns1:IncorrectApiPasswordFault/>
#         </detail>
#      </SOAP-ENV:Fault>
#   </SOAP-ENV:Body>
#</SOAP-ENV:Envelope>

#<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://www.zasilkovna.cz/api/soap.wsdl" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#   <SOAP-ENV:Body>
#      <ns1:packetStatusResponse>
#         <packetStatusResult>
#            <ns1:dateTime>2019-01-28T10:24:13</ns1:dateTime>
#            <ns1:statusCode>1</ns1:statusCode>
#            <ns1:codeText>received data</ns1:codeText>
#            <ns1:statusText>Internetový obchod předal informace o zásilce.</ns1:statusText>
#            <ns1:branchId>0</ns1:branchId>
#            <ns1:destinationBranchId>0</ns1:destinationBranchId>
#            <ns1:externalTrackingCode xsi:nil="true"/>
#            <ns1:isReturning>false</ns1:isReturning>
#            <ns1:storedUntil xsi:nil="true"/>
#         </packetStatusResult>
#      </ns1:packetStatusResponse>
#   </SOAP-ENV:Body>
#</SOAP-ENV:Envelope>