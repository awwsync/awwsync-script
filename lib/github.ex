defmodule Github do
  @client Tentacat.Client.new(%{access_token: System.get_env("GITHUB_ACCESS_TOKEN", "")})
  @watched_events [
    "closed",
    "commented",
    "committed",
    "convert_to_draft",
    "cross-referenced",
    "mentioned",
    "merged",
    "ready_for_review",
    "reopened",
    "review_requested",
    "reviewed"
  ]

  # @spec get_events(DateTime.t(), Tentacat.t(), String.t()) :: {200, any, any}
  # def events_fetcher(since_date, client, url) do
  #   {200, data, _response} = client.get(url)
  # end

  def events_fetcher() do
  end

  @spec get_events(String.t(), String.t(), DateTime.t()) :: [any]
  @spec get_events(String.t(), String.t(), DateTime.t(), String.t()) :: [any]
  def get_events(owner, repo, since_date, pagination_url \\ nil) do
    {{200, data, _response}, pagination_url, _client_auth} =
      Tentacat.get("repos/#{owner}/#{repo}/issues/events", @client)

    IO.puts(pagination_url)

    {:ok, first_event_date, _offset} =
      List.first(data) |> get_in(["created_at"]) |> DateTime.from_iso8601()

    case DateTime.compare(first_event_date, since_date) do
      :gt -> data
      res when res in [:lt, :eq] -> [data | get_events(owner, repo, since_date, pagination_url)]
    end
  end

  def parse_events(events) do
    Enum.filter(events, fn %{"event" => event_type} ->
      Enum.member?(@watched_events, event_type)
    end)
  end
end
