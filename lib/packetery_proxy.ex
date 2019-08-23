defmodule PacketeryProxy do
  @moduledoc false

  use Soapex.Proxy,
    wsdl_path: "http://www.zasilkovna.cz/api/soap.wsdl"
end
