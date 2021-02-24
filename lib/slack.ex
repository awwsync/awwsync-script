defmodule Slack do
  defp get_events_by_actor(events) do
    events_by_actor =
      Enum.reduce(events, %{}, fn %{:actor => %{"login" => actor_login}} = event, map ->
        case Map.get(map, actor_login) do
          nil -> Map.put(map, actor_login, [event])
          arr -> Map.put(map, actor_login, [event | arr])
        end
      end)

    events_by_actor
  end

  def get_events_description(events) do
    events
    |> Enum.map(fn %{:event_type => event_type} -> "- #{event_type}\n" end)
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
