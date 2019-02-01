defmodule Soapex.Fetcher do
  @moduledoc false

  import SweetXml
  import Soapex.Util

  @spec get_files(String.t()) :: Map.t()
  def get_files(path) do
    wsdl = get_content(path)
    parsed_imports = nil #get_imports(wsdl)

    {:ok, %{wsdl: wsdl, imports: parsed_imports}}
  end

  defp get_imports(wsdl_content) do
    wsdl_ns =             get_schema_prefix(wsdl_content, "http://schemas.xmlsoap.org/wsdl/")
    schema_ns =           get_schema_prefix(wsdl_content, "http://www.w3.org/2001/XMLSchema")
    {version, soap_ns} =  get_soap_version(wsdl_content)

    wsdl_content
    |> xpath(~x"//#{ns("definitions",wsdl_ns)}/#{ns("types",wsdl_ns)}/#{ns("schema",schema_ns)}/#{ns("import",schema_ns)}"l)
    |> Enum.map(fn el -> xpath(el, ~x".", namespace: ~x"./@namespace"s, schema_location: ~x"./@schemaLocation"s) end)
    |> Enum.map(&fetch_import/1)
  end

  defp fetch_import(import) do
    %{schema_location: path} = import

    Map.merge(import, %{
      content: get_content(path)
    });
  end

  defp valid_url?(url) do
    case URI.parse(url) do
      %URI{scheme: nil} -> {:error, "No scheme"}
      %URI{host: nil} -> {:error, "No host"}
      _ -> {:ok, url}
    end
  end

  defp get_content(path) do
    case valid_url?(path) do
      {:ok, url} ->
        %HTTPoison.Response{body: wsdl} = HTTPoison.get!(url, [], follow_redirect: true, max_redirect: 3)
        wsdl
      {:error, _} ->
        {:ok, wsdl} = File.read(path)
        wsdl
    end
  end

end
