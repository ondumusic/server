defmodule Ondu.AWSReqClient do
  @moduledoc false
  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, body, headers, _http_opts) do
    request = Req.new(decode_body: false, retry: false)

    case Req.request(request, method: method, url: url, body: body, headers: headers) do
      {:ok, response} ->
        {:ok,
         %{
           status_code: response.status,
           headers: Req.get_headers_list(response),
           body: response.body
         }}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
end
