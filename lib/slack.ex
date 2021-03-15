defmodule Slack do
  defp get_events_by_actor(events) do
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

  def prepare_message(events) do
    # IO.inspect(events)
    # https://api.slack.com/reference/surfaces/formatting
    events_by_actor = events |> get_events_by_actor()

    message =
      for {actor, events} <- events_by_actor,
          do: "\n\n*#{actor}*\n#{get_events_description(events)}",
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
