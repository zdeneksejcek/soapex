defmodule Soapex.Request do
  @moduledoc false

  def create_request(wsdl, service, bind, op) do
    XmlBuilder.document(:person, ["xmlns:soap": 1, a: 2], "Josh") |> XmlBuilder.generate
  end

end
