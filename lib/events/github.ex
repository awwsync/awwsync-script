defmodule Events.Github do
  @watched_timeline_events [
    "closed",
    "commented",
    "reviewed",
    "review_requested",
    "committed"
  ]

  @spec get_events(String.t(), String.t(), DateTime.t(), list(Regex.t())) ::
          list(Events.AwwSync.t())
  def get_events(owner, repo, since_date, excluded_users \\ []) do
    issues_events = get_issues_with_timeline_events(owner, repo, since_date)
    merged_prs = get_merged_prs_events(owner, repo, since_date)
    releases = get_releases_events(owner, repo, since_date)

    events = issues_events ++ merged_prs ++ releases

    Enum.filter(events, fn %{:actor => %{"login" => login}} ->
      !Enum.any?(excluded_users, fn user_regex -> String.match?(login, user_regex) end)
    end)
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
  @spec get_issues_with_timeline_events(String.t(), String.t(), DateTime.t()) ::
          [any]
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

        awwsync_timeline_events =
          timeline
          |> Enum.filter(fn event ->
            check_timeline_event_date(event, since_date) &&
              event["event"] in @watched_timeline_events
          end)
          |> Enum.map(fn event -> timeline_event_to_awwsync_event(event, issue) end)

        Map.put(issue, "timeline", awwsync_timeline_events)
      end)

    new_issues =
      issues_with_timeline
      |> Enum.filter(fn %{"created_at" => creation_date} ->
        Utils.Dates.is_date_gt_or_eq(creation_date, since_date)
      end)
      |> Enum.map(&new_issue_to_awwsync_event/1)

    timeline_events =
      issues_with_timeline
      |> Enum.map(fn issue -> issue["timeline"] end)
      |> List.flatten()

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
    %{
      "author" => actor,
      "name" => name,
      "html_url" => html_url,
      "id" => id,
      "body" => body,
      "published_at" => release_publication_date
    } = release

    {:ok, dt_date, _offset} = DateTime.from_iso8601(release_publication_date)

    %Events.AwwSync{
      platform: "github",
      event_type: "release",
      actor: actor,
      date: dt_date,
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
    %{"actor" => actor, "issue" => issue, "created_at" => merged_at} = pr

    %{
      "title" => issue_title,
      "body" => body,
      "html_url" => html_url,
      "id" => id
    } = issue

    {:ok, dt_date, _offset} = DateTime.from_iso8601(merged_at)

    %Events.AwwSync{
      platform: "github",
      event_type: "merged_pr",
      actor: actor,
      date: dt_date,
      subject: %{
        name: issue_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: nil
    }
  end

  @spec new_issue_to_awwsync_event(any) :: Events.AwwSync.t()
  defp new_issue_to_awwsync_event(event) do
    %{
      "user" => creator,
      "title" => issue_title,
      "body" => body,
      "html_url" => html_url,
      "id" => id,
      "created_at" => created_at
    } = event

    {:ok, dt_date, _offset} = DateTime.from_iso8601(created_at)

    %Events.AwwSync{
      platform: "github",
      event_type: "new_issue",
      actor: creator,
      date: dt_date,
      subject: %{
        name: issue_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: nil
    }
  end

  @spec timeline_event_to_awwsync_event(any, any) :: Events.AwwSync.t()
  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event, issue)
       when event_type == "closed" do
    %{"actor" => actor, "created_at" => event_date} = event

    %{
      "title" => issue_title,
      "body" => body,
      "html_url" => html_url,
      "id" => id
    } = issue

    {:ok, dt_date, _offset} = DateTime.from_iso8601(event_date)

    %Events.AwwSync{
      platform: "github",
      event_type: "issue_closed",
      actor: actor,
      date: dt_date,
      subject: %{
        name: issue_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: nil
    }
  end

  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event, issue)
       when event_type == "commented" do
    %{
      "user" => actor,
      "html_url" => comment_url,
      "body" => comment_body,
      "created_at" => event_date
    } = event

    %{"body" => issue_body, "html_url" => html_url, "id" => id, "title" => pr_title} = issue

    {:ok, dt_date, _offset} = DateTime.from_iso8601(event_date)

    %Events.AwwSync{
      platform: "github",
      event_type: "issue_comment",
      actor: actor,
      date: dt_date,
      subject: %{
        name: pr_title,
        url: html_url,
        id: id,
        body: issue_body
      },
      event_payload: %{
        html_url: comment_url,
        body: comment_body
      }
    }
  end

  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event, issue)
       when event_type == "reviewed" do
    %{"user" => actor, "state" => state, "submitted_at" => event_date} = event
    %{"body" => body, "html_url" => html_url, "id" => id, "title" => pr_title} = issue
    {:ok, dt_date, _offset} = DateTime.from_iso8601(event_date)

    %Events.AwwSync{
      platform: "github",
      event_type: "pr_review",
      actor: actor,
      date: dt_date,
      subject: %{
        name: pr_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: %{
        state: state
      }
    }
  end

  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event, issue)
       when event_type == "review_requested" do
    %{"actor" => actor, "requested_reviewer" => requested_reviewer, "created_at" => event_date} =
      event

    %{"body" => body, "html_url" => html_url, "id" => id, "title" => pr_title} = issue

    {:ok, dt_date, _offset} = DateTime.from_iso8601(event_date)

    %Events.AwwSync{
      platform: "github",
      event_type: "review_request",
      actor: actor,
      date: dt_date,
      subject: %{
        name: pr_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: %{
        requested_reviewer: requested_reviewer
      }
    }
  end

  defp timeline_event_to_awwsync_event(%{"event" => event_type} = event, issue)
       when event_type == "committed" do
    %{
      "author" => actor,
      "message" => message,
      "html_url" => commit_url
    } = event

    %{"date" => event_date} = actor

    %{"body" => body, "html_url" => html_url, "id" => id, "title" => pr_title} = issue

    {:ok, dt_date, _offset} = DateTime.from_iso8601(event_date)

    %Events.AwwSync{
      platform: "github",
      event_type: "commit",
      actor: Map.put(actor, "login", hd(String.split(actor["email"], "@"))),
      date: dt_date,
      subject: %{
        name: pr_title,
        url: html_url,
        id: id,
        body: body
      },
      event_payload: %{
        message: message,
        commit_url: commit_url
      }
    }
  end

  defp check_timeline_event_date(%{"committer" => %{"date" => event_date}}, since_date) do
    Utils.Dates.is_date_gt_or_eq(event_date, since_date)
  end

  defp check_timeline_event_date(%{"created_at" => event_date}, since_date) do
    Utils.Dates.is_date_gt_or_eq(event_date, since_date)
  end

  defp check_timeline_event_date(%{"submitted_at" => event_date}, since_date) do
    Utils.Dates.is_date_gt_or_eq(event_date, since_date)
  end

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
end
