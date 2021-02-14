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
  @spec get_issues_events(String.t(), String.t(), DateTime.t()) :: [any]
  def get_issues_events(owner, repo, since_date) do
    issues_url = get_repo_issues_url(owner, repo)

    issues =
      fetch_from_gh(issues_url, %{
        "state" => "all",
        "sort" => "updated",
        "direction" => "desc",
        "since" => since_date
      })

    IO.inspect(issues)

    issues_with_timeline =
      Enum.map(issues, fn %{"number" => issue_number} = issue ->
        timeline_url = get_issue_timeline_events_url(owner, repo, issue_number)
        timeline = fetch_from_gh(timeline_url)

        Map.put(issue, "timeline", timeline)
      end)

    issues_with_timeline
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

  defp fetch_from_gh(url, query_params \\ %{}) do
    query_string = URI.encode_query(query_params)
    IO.puts(url <> "?#{query_string}")

    %{:body => data} =
      HTTPoison.get!(url <> "?#{query_string}", [
        {"Authorization", "token " <> System.get_env("GITHUB_ACCESS_TOKEN", "")}
      ])

    {:ok, json_data} = Jason.decode(data)
    json_data
  end
end
