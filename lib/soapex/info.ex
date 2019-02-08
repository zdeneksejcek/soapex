defmodule Soapex.Info do
  @moduledoc false

  def get(wsdl) do
    wsdl.services
    |> Enum.map(fn ser -> %{
      name: ser.name,
      ports: ser.ports |> Enum.map(fn port -> get_port(port, wsdl) end)
    } end)
  end

  defp get_port(port, wsdl) do
    %{name:     port.name,
      protocol: port.protocol,
      location: port.location,

      operations: get_operations(port.binding, wsdl)}
  end

  defp get_operations(bin_name, wsdl) do
    binding =         wsdl.bindings |> Enum.find(fn b -> b.name == bin_name end)
    port_type_name =  remove_ns(binding.type)
    port_type =       wsdl.port_types |> Enum.find(fn pt -> pt.name == port_type_name end)

    binding.operations
    |> Enum.map(fn op -> get_operation(op, port_type, wsdl) end)
  end

  defp get_operation(op, port_type, wsdl) do
    oper = port_type.operations[op.name]
    input_message_name =  remove_ns(oper.input_message)
    output_message_name = remove_ns(oper.output_message)

    oper
    |> Map.put(:name, op.name)
    |> Map.put(:soap_action,  op.soap.soap_action)
    |> Map.put(:soap_style,   op.soap.style)
    |> Map.put(:input_message_ns, op.input[:namespace])
    |> Map.put(:output_message_ns, op.output[:namespace])
    |> Map.put(:input_message,  get_message(input_message_name, wsdl))
    |> Map.put(:output_message, get_message(output_message_name, wsdl))
    |> Map.put(:faults,         get_faults(oper.faults, wsdl))
  end

  defp get_message(mess_name, wsdl) do
    mess_name = remove_ns(mess_name)

    wsdl.messages |> Enum.find(fn m -> m.name == mess_name end)
  end

  defp get_faults(faults, wsdl) do
    faults
    |> Enum.map(fn f -> Map.put(f, :message, get_message(f.message, wsdl)) end)
  end

  defp remove_ns(name) do
    case String.split(name, ":", trim: true, parts: 2) do
      [_ns, rest] -> rest
      [rest]      -> rest
      []          -> raise "missing name"
    end
  end


end
