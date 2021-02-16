defmodule Github do
  # for new releases
  @spec get_repo_releases_url(String.t(), String.t()) :: String.t()
  defp get_repo_releases_url(owner, repo) do
    "https://api.github.com/repos/#{owner}/#{repo}/releases"
  end

  # for new PRs/issues
  @spec get_repo_issues_url(String.t(), String.t()) :: String.t()
  defp get_repo_issues_url(owner, repo) do
    "https://api.github.com/repos/#{owner}/#{repo}/issues"
  end

  @spec get_issues_events_url(String.t(), String.t()) :: String.t()
  defp get_issues_events_url(owner, repo) do
    "https://api.github.com/repos/#{owner}/#{repo}/issues/events"
  end

  # for comments/etc on a particular issue
  @spec get_issue_timeline_events_url(String.t(), String.t(), Integer.t()) :: String.t()
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

    issues_with_timeline =
      Enum.map(issues, fn %{"number" => issue_number} = issue ->
        timeline_url = get_issue_timeline_events_url(owner, repo, issue_number)
        timeline = fetch_from_gh(timeline_url)

        Map.put(issue, "timeline", timeline)
      end)

    issues_with_timeline
  end

  @doc """
  Retrieves merged PRs
  """
  @spec get_merged_prs(String.t(), String.t(), DateTime.t(), Integer.t(), List.t()) :: list
  def get_merged_prs(owner, repo, since_date, page \\ 1, acc \\ []) do
    url = get_issues_events_url(owner, repo)
    events = fetch_from_gh(url, %{page: page})
    new_acc = acc ++ events

    {:ok, last_event_date, _offset} =
      List.last(events) |> get_in(["created_at"]) |> DateTime.from_iso8601()

    case DateTime.compare(last_event_date, since_date) do
      res when res in [:gt, :eq] ->
        get_merged_prs(owner, repo, since_date, page + 1, new_acc)

      :lt ->
        merged_event = "merged"

        Enum.filter(new_acc, fn %{"event" => event_type, "created_at" => event_date} ->
          {:ok, event_dt, _offset} = DateTime.from_iso8601(event_date)
          DateTime.compare(event_dt, since_date) in [:gt, :eq] && event_type === merged_event
        end)
    end
  end

  @spec get_releases(String.t(), String.t(), DateTime.t()) :: list
  def get_releases(owner, repo, since_date) do
    url = get_repo_releases_url(owner, repo)
    releases = fetch_from_gh(url)

    Enum.filter(releases, fn %{"published_at" => release_publication_date} ->
      case release_publication_date do
        # filter out draft releases (not published yet)
        nil ->
          false

        _ ->
          {:ok, release_publication_dt, _offset} = DateTime.from_iso8601(release_publication_date)

          DateTime.compare(release_publication_dt, since_date) in [:gt, :eq]
      end
    end)
  end

  @spec fetch_from_gh(String.t(), any) :: any
  def fetch_from_gh(url, query_params \\ %{}) do
    query_string = URI.encode_query(query_params)

    %{:body => data} =
      HTTPoison.get!(url <> "?#{query_string}", [
        {"Authorization", "token " <> System.get_env("GITHUB_ACCESS_TOKEN", "")}
      ])

    {:ok, json_data} = Jason.decode(data)
    json_data
  end
end
