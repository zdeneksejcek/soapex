defmodule BlzProxy do
  @moduledoc false

  use Soapex.Proxy,
      wsdl_path: "./samples/blz.wsdl"

end
