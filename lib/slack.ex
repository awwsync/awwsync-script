defmodule Slack do
  defp get_events_by_issue(events) do
    events_by_issue =
      Enum.reduce(events, %{}, fn %{:subject => %{:name => issue_name}} = event, map ->
        case Map.get(map, issue_name) do
          nil -> Map.put(map, issue_name, [event])
          arr -> Map.put(map, issue_name, [event | arr])
        end
      end)

    events_by_issue
  end

  @spec get_events_description(any) :: binary
  def get_events_description(events) do
    events
    |> Enum.map(fn event -> "- #{Events.Github.Descriptions.get_event_description(event)}\n" end)
    |> Enum.join("\n")
  end

  @spec sort_events_by_date([Events.AwwSync.t()]) :: [Events.AwwSync.t()]
  def sort_events_by_date(events) do
    Enum.sort_by(events, & &1.date, {:desc, DateTime})
  end

  def prepare_message(events) do
    # https://api.slack.com/reference/surfaces/formatting
    events_by_issue = events |> sort_events_by_date() |> get_events_by_issue()

    message =
      for {issue, events} <- events_by_issue,
          do: "\n\n*#{issue}*\n#{get_events_description(events)}",
          into: ""

    message
  end

  def send_message(message \\ "hello") do
    payload = %{
      text: message
    }

    HTTPoison.post!(System.get_env("SLACK_WEBHOOK_URL"), Jason.encode!(payload))
  end
end
