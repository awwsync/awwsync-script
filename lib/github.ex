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

  @spec get_events(String.t(), String.t(), DateTime.t(), Integer.t(), List.t()) :: [any]
  def get_events(owner, repo, since_date, page \\ 1, acc \\ []) do
    events = events_fetcher(owner, repo, page)
    new_acc = acc ++ events

    {:ok, last_event_date, _offset} =
      List.last(events) |> get_in(["created_at"]) |> DateTime.from_iso8601()

    case DateTime.compare(last_event_date, since_date) do
      res when res in [:gt, :eq] ->
        get_events(owner, repo, since_date, page + 1, new_acc)

      :lt ->
        filter_events(new_acc, since_date)
    end
  end

  @spec filter_events([any], DateTime.t()) :: [any]
  def filter_events(events, since_date) do
    Enum.filter(events, fn event ->
      is_event_applicable?(event, since_date)
    end)
  end

  defp is_event_applicable?(%{"event" => event_type, "created_at" => event_date}, since_date) do
    {:ok, event_dt, _offset} = DateTime.from_iso8601(event_date)

    DateTime.compare(event_dt, since_date) in [:gt, :eq] &&
      Enum.member?(@watched_events, event_type)
  end

  @spec events_fetcher(String.t(), String.t(), Integer.t()) :: [any]
  defp events_fetcher(owner, repo, page) do
    {{200, data, _response}, _pagination_url, _client_auth} =
      Tentacat.get("repos/#{owner}/#{repo}/issues/events?page=#{page}", @client)

    data
  end
end
