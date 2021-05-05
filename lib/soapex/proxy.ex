defmodule Soapex.Proxy do
  @moduledoc false

  defmacro __using__(parms) do
    quote bind_quoted: [parms: parms] do
      HTTPoison.start()
      @moduledoc "This is **SOAPex** proxy module"

      wsdl = Soapex.Wsdl.get_wsdl(parms[:wsdl_path])
      @wsdl wsdl
      @t_wsdl Soapex.Info.get_operations(wsdl)

      Enum.each(@t_wsdl, fn {service_name, service_value} ->
        Enum.each(service_value, fn {port_name, port_value} ->
          def unquote(:"#{Macro.underscore(port_name)}")() do
            {unquote(Macro.escape(service_name)), unquote(Macro.escape(port_name))}
          end

          Enum.each(port_value.operations, fn {op_name, op_value} ->
            params =
              op_value.input_message.parts
              |> Enum.map(fn p -> Macro.var(:"#{Macro.underscore(p.name)}", __MODULE__) end)

            params_list =
              op_value.input_message.parts
              |> Enum.map(fn p ->
                {"#{p.name}", Macro.var(:"#{Macro.underscore(p.name)}", __MODULE__)}
              end)

            @doc """
              # Parameters:
              #{Soapex.Docs.parameters(op_value)}


              # Faults:
              #{Soapex.Docs.faults(op_value)}
            """
            def unquote(:"#{Macro.underscore(op_name)}")(
                  {unquote(Macro.escape(service_name)), unquote(Macro.escape(port_name))} =
                    port_path,
                  unquote_splicing(params),
                  opts \\ []
                ) do
              operation_name = unquote(op_name)
              params_map = unquote(params_list) |> Enum.into(%{})

              Soapex.Request.create_request(
                @t_wsdl,
                @wsdl,
                port_path,
                operation_name,
                params_map,
                opts
              )
            end
          end)
        end)
      end)
    end
  end
end
