defmodule Soapex.Fetcher do
  @moduledoc false

  import SweetXml
  import Soapex.Util

  @spec get_files(String.t()) :: Map.t()
  def get_files(path) do
    wsdl_root = get_root(path)
    parsed_imports = get_imports(wsdl_root)

    {:ok, %{wsdl: wsdl_root, imports: parsed_imports}}
  end

  defp get_imports(wsdl_root) do
    wsdl_root
    |> ns_xpath(~x"//wsdl:definitions/wsdl:types/xsd:schema/xsd:import"l)
    |> Enum.map(fn el -> ns_xpath(el, ~x".", namespace: ~x"./@namespace"s, schema_location: ~x"./@schemaLocation"s) end)
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
        wsdl |> parse(namespace_conformant: true)
      {:error, _} ->
        {:ok, wsdl} = File.read(path)
        wsdl |> parse(namespace_conformant: true)
    end
  end

end
