defmodule Events.Github do
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
  @spec get_issues_with_timeline_events(String.t(), String.t(), DateTime.t()) :: [any]
  def get_issues_with_timeline_events(owner, repo, since_date) do
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

    new_issues =
      issues_with_timeline
      |> Enum.filter(fn %{"created_at" => creation_date} ->
        Utils.Dates.is_date_gt_or_eq(creation_date, since_date)
      end)
      |> Enum.map(&new_issue_to_awwsync_event/1)

    timeline_events =
      issues_with_timeline
      |> Enum.filter(fn %{"created_at" => event_date} ->
        Utils.Dates.is_date_gt_or_eq(event_date, since_date)
      end)
      |> Enum.map(fn %{"timeline" => timeline} -> timeline_event_to_awwsync_event(timeline) end)

    new_issues ++ timeline_events
  end

  @doc """
  Retrieves merged PRs
  """
  @spec get_merged_prs_events(String.t(), String.t(), DateTime.t(), Integer.t(), List.t()) :: list
  def get_merged_prs_events(owner, repo, since_date, page \\ 1, acc \\ []) do
    url = get_issues_events_url(owner, repo)
    events = fetch_from_gh(url, %{page: page})
    new_acc = acc ++ events

    {:ok, last_event_date, _offset} =
      List.last(events) |> get_in(["created_at"]) |> DateTime.from_iso8601()

    case DateTime.compare(last_event_date, since_date) do
      res when res in [:gt, :eq] ->
        get_merged_prs_events(owner, repo, since_date, page + 1, new_acc)

      :lt ->
        merged_event = "merged"

        new_acc
        |> Enum.filter(fn %{"event" => event_type, "created_at" => event_date} ->
          Utils.Dates.is_date_gt_or_eq(event_date, since_date) && event_type === merged_event
        end)
        |> Enum.map(&merged_pr_to_awwsync_event/1)
    end
  end

  @spec get_releases_events(String.t(), String.t(), DateTime.t()) :: list
  def get_releases_events(owner, repo, since_date) do
    url = get_repo_releases_url(owner, repo)
    releases = fetch_from_gh(url)

    releases
    |> Enum.filter(fn %{"published_at" => release_publication_date} ->
      case release_publication_date do
        # filter out draft releases (not published yet)
        nil ->
          false

        _ ->
          Utils.Dates.is_date_gt_or_eq(release_publication_date, since_date)
      end
    end)
    |> Enum.map(&release_to_awwsync_event/1)
  end

  @spec fetch_from_gh(String.t(), any) :: any
  def fetch_from_gh(url, query_params \\ %{}) do
    query_string = URI.encode_query(query_params)

    %{:body => data} =
      HTTPoison.get!(url <> "?#{query_string}", [
        {"Authorization", "token " <> System.get_env("GITHUB_ACCESS_TOKEN", "")},
        {"Accept", "application/vnd.github.mockingbird-preview+json"}
      ])

    {:ok, json_data} = Jason.decode(data)
    json_data
  end

  @spec release_to_awwsync_event(map()) :: Events.AwwSync.t()
  defp release_to_awwsync_event(release) do
    %{"author" => actor, "name" => name, "html_url" => html_url, "id" => id, "body" => body} =
      release

    %Events.AwwSync{
      platform: "github",
      event_type: "release",
      actor: actor,
      subject: %{
        id: id,
        url: html_url,
        name: name,
        body: body
      },
      event_payload: nil
    }
  end

  @spec merged_pr_to_awwsync_event(any) :: Events.AwwSync.t()
  defp merged_pr_to_awwsync_event(pr) do
    %{"actor" => actor, "issue" => issue} = pr

    %Events.AwwSync{
      platform: "github",
      event_type: "merged_pr",
      actor: actor,
      subject: issue,
      event_payload: nil
    }
  end

  defp new_issue_to_awwsync_event(event) do
    %{
      "user" => creator,
      "title" => issue_title,
      "body" => body,
      "html_url" => html_url,
      "id" => id
    } = event

    %Events.AwwSync{
      platform: "github",
      event_type: "new_issue",
      actor: creator,
      subject: %{
        name: issue_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: nil
    }
  end

  @spec timeline_event_to_awwsync_event(any) :: Events.AwwSync.t()
  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event)
       when event_type == "closed" do
    %{"actor" => actor} = event

    %Events.AwwSync{
      platform: "github",
      event_type: "new_issue",
      actor: actor,
      subject: %{
        name: issue_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: nil
    }
  end

  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event)
       when event_type == "commented" do
    %{"actor" => actor} = event

    %Events.AwwSync{
      platform: "github",
      event_type: "new_issue",
      actor: actor,
      subject: %{
        name: issue_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: nil
    }
  end

  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event)
       when event_type == "reviewed" do
    %{"actor" => actor} = event

    %Events.AwwSync{
      platform: "github",
      event_type: "new_issue",
      actor: actor,
      subject: %{
        name: issue_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: nil
    }
  end

  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event)
       when event_type == "review_requested" do
    %{"actor" => actor} = event
    nil
  end

  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event)
       when event_type == "committed" do
    %{"actor" => actor} = event

    %Events.AwwSync{
      platform: "github",
      event_type: "new_issue",
      actor: actor,
      subject: %{
        name: issue_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: nil
    }
  end
end
