defmodule Soapex.Fetcher do
  @moduledoc false

  import SweetXml
  import Soapex.Util

  @spec get_files(String.t()) :: Map.t()
  def get_files(path) do
    wsdl_root = get_root(path)
    nss = get_namespaces(wsdl_root)

    parsed_imports = get_imports(wsdl_root, nss)

    {:ok, %{wsdl: wsdl_root, imports: parsed_imports, nss: nss}}
  end

  defp get_imports(wsdl_root, nss) do
    wsdl_root
    |> xpath(~x"//#{ns("definitions",nss.wsdl)}/#{ns("types",nss.wsdl)}/#{ns("schema",nss.schema)}/#{ns("import",nss.schema)}"l)
    |> Enum.map(fn el -> xpath(el, ~x".", namespace: ~x"./@namespace"s, schema_location: ~x"./@schemaLocation"s) end)
    |> Enum.map(&fetch_import/1)
  end

  defp fetch_import(import) do
    %{schema_location: path} = import

    Map.merge(import, %{
      content: get_root(path)
    });
  end

  defp valid_url?(url) do
    case URI.parse(url) do
      %URI{scheme: nil} -> {:error, "No scheme"}
      %URI{host: nil} -> {:error, "No host"}
      _ -> {:ok, url}
    end
  end

  defp get_root(path) do
    case valid_url?(path) do
      {:ok, url} ->
        %HTTPoison.Response{body: wsdl} = HTTPoison.get!(url, [], follow_redirect: true, max_redirect: 3)
        wsdl |> xpath(~x".")
      {:error, _} ->
        {:ok, wsdl} = File.read(path)
        wsdl |> xpath(~x".")
    end
  end

end
