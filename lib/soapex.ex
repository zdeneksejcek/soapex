defmodule Soapex do
  @moduledoc """
  Documentation for Soupex.
  """

  alias Soapex.Request
  alias Soapex.Wsdl
  alias Soapex.Info

  def get_info() do
    wsdl = Wsdl.get_wsdl("./samples/packetery.wsdl")
    info = Info.get_operations(wsdl)

    Enum.each(info, &IO.inspect/1)
  end

  def call() do
    wsdl = Wsdl.get_wsdl("./samples/packetery.wsdl")
    info = Info.get_operations(wsdl)

    service = "PacketeryService"
    port = "PacketeryPort"
    operation = "createPacket"

    api_password = "db27c2f27c05508daecbd82cf69902f3"

    #    attributes = %{
    #      "number" => 125,
    #      "name"  => "Jan",
    #      "surname" => "Tleskac",
    #      "company" => "Jezek s.r.o.",
    #      "email" => "jan@stinadla.cz",
    #      "phone" => "732456789",
    #      "addressId" => 129,
    #      "cod" => 100,
    #      "currency" => "CZK",
    #      "value" => 250,
    #      "weight" => 1,
    #      "eshop" => "mujshop",
    #      "adultContent" => 0,
    #      "street" => "Jana Masaryka",
    #      "houseNumber" => "3",
    #      "city" => "Praha",
    #      "province" => "Praha",
    #      "zip" => "12000"
    #    }

    attributes = %{
      "addressId" => 129,
      "adultContent" => 0,
      "city" => "Praha",
      "cod" => "100",
      "company" => "Topicblab",
      "currency" => "CZK",
      "email" => "mbeazey4@bloglovin.com",
      "eshop" => "mujshop",
      "houseNumber" => "760",
      "name" => "Marcia",
      "number" => "132",
      "phone" => "731222333",
      "street" => "Marquette",
      "surname" => "Beazey",
      "value" => "250",
      "weight" => 1,
      "province" => "Praha",
      "zip" => "12000"
    }

    op_info = info[service][port][:operations][operation]

    Request.create_request(info, wsdl, {service, port}, operation, %{
      "apiPassword" => api_password,
      "attributes" => attributes
    })
  end

  #    %{name: "number", type: "string24"},
  #    %{name: "name", type: "string32"},
  #    %{name: "surname", type: "string32"},
  #    %{name: "company", nillable: true, type: "string32"},
  #    %{name: "email", nillable: true, type: "email"},
  #    %{name: "phone", nillable: true, type: "phone"},
  #    %{name: "addressId", type: :unsigned_int},
  #    %{name: "cod", nillable: true, type: "money"},
  #    %{name: "currency", nillable: true, type: "currency"},
  #    %{name: "value", type: "money"},
  #    %{name: "weight", nillable: true, type: "weight"},
  #    %{name: "eshop", nillable: true, type: "string64"},
  #    %{name: "adultContent", nillable: true, type: :unsigned_int},
  #    %{name: "deliverOn", nillable: true, type: :date},
  #    %{name: "street", nillable: true, type: "string64"},
  #    %{name: "houseNumber", nillable: true, type: "string16"},
  #    %{name: "city", nillable: true, type: "string32"},
  #    %{name: "province", nillable: true, type: "string32"},
  #    %{name: "zip", nillable: true, type: "zip"},
end
