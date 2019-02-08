defmodule EbayProxy do
  @moduledoc false

  use Soapex.Proxy,
      wsdl_path: "./samples/ebay.wsdl"

end
