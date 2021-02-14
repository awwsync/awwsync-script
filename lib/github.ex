defmodule Github do
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

  # for new releases
  defp get_repo_releases_url(owner, repo) do
    "https://api.github.com/repos/#{owner}/#{repo}/releases"
  end

  # for new PRs/issues
  defp get_repo_issues_url(owner, repo) do
    "https://api.github.com/repos/#{owner}/#{repo}/issues"
  end

  defp get_issue_events_url(owner, repo) do
    "https://api.github.com/repos/#{owner}/#{repo}/issues/events"
  end

  # for comments/etc on a particular issue
  defp get_issue_timeline_events_url(owner, repo, issue_number) do
    "https://api.github.com/repos/#{owner}/#{repo}/issues/#{issue_number}/timeline"
  end

  @doc """
  Retrieves events related to issues (PRs are also considered issues)
  - New issues/PRs
  - Closed issues/PRs
  - Comments
  - Reviews
  - Review requests
  - Merged PRs
  - Commits
  """
  @spec get_events(String.t(), String.t(), DateTime.t(), Integer.t(), List.t()) :: [any]
  def get_issues_events(owner, repo, since_date, page \\ 1, acc \\ []) do
    url = get_repo_issues_url(owner, repo)
    issues = fetch(url)
    new_acc = acc ++ issues

    {:ok, last_event_date, _offset} =
      List.last(events) |> get_in(["created_at"]) |> DateTime.from_iso8601()

    case DateTime.compare(last_event_date, since_date) do
      res when res in [:gt, :eq] ->
        get_issues_events(owner, repo, since_date, page + 1, new_acc)

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
  defp fetch(url, query_params \\ %{}) do
    querystring = URI.encode_query(query_params)

    {:ok, response} =
      HTTPoison.get!(url <> querystring, [
        {"Authorization", "token " <> System.get_env(GITHUB_ACCESS_TOKEN, "")}
      ])

    response
  end
end
