defmodule Soapex.Proxy do
  @moduledoc false

  defmacro __using__(parms) do
    quote bind_quoted: [parms: parms] do
      @moduledoc "This is **SOAPex** proxy module"

      @t_wsdl Soapex.Info.get(Soapex.Wsdl.get_wsdl(parms[:wsdl_path]))

      Enum.each(@t_wsdl, fn ser ->
        Enum.each(ser.ports, fn port ->
          def unquote(:"#{Macro.underscore(port.name)}")() do
            {unquote(Macro.escape(ser.name)), unquote(Macro.escape(port.name))}
          end

          Enum.each(port.operations, fn op ->
            params = op.input_message.parts |> Enum.map(fn p -> Macro.var(:"#{Macro.underscore(p.name)}", __MODULE__) end)
            params_list = op.input_message.parts |> Enum.map(fn p -> {"#{p.name}", Macro.var(:"#{Macro.underscore(p.name)}", __MODULE__)} end)

            @doc """
              Operation **#{op.name}**

              #{Soapex.Docs.operation(op)}
            """
            def unquote(:"#{Macro.underscore(op.name)}")(
                  {unquote(Macro.escape(ser.name)), unquote(Macro.escape(port.name))} = port_path,
                  unquote_splicing(params)
                  ) do
              operation_name = unquote(op.name)
              params_map = unquote(params_list)  |> Enum.into(%{})

              Soapex.Request.create_request(@t_wsdl, port_path, operation_name, params_map)
            end
          end)
        end)
      end)
    end
  end
end