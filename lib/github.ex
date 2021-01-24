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

  @spec events_fetcher(String.t(), String.t(), Integer.t()) :: [any]
  defp events_fetcher(owner, repo, page) do
    IO.puts("repos/#{owner}/#{repo}/issues/events?page=#{page}")

    {{200, data, _response}, _pagination_url, _client_auth} =
      Tentacat.get("repos/#{owner}/#{repo}/issues/events?page=#{page}", @client)

    data
  end

  @spec get_events(String.t(), String.t(), DateTime.t(), Integer.t(), List.t()) :: [any]
  def get_events(owner, repo, since_date, page \\ 0, acc \\ []) do
    events = events_fetcher(owner, repo, page)
    new_acc = [acc | events]

    {:ok, last_event_date, _offset} =
      List.last(events) |> get_in(["created_at"]) |> DateTime.from_iso8601()

    case DateTime.compare(last_event_date, since_date) do
      res when res in [:gt, :eq] ->
        get_events(owner, repo, since_date, page + 1, new_acc)

      :lt ->
        new_acc
    end
  end

  def parse_events(events) do
    Enum.filter(events, fn %{"event" => event_type} ->
      Enum.member?(@watched_events, event_type)
    end)
  end
end
