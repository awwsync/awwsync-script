defmodule Slack do
  def prepare_message(events) do
    events_by_actor =
      Enum.reduce(events, %{}, fn %{"actor" => %{"id" => actor_id}} = event, map ->
        case Map.get(map, actor_id) do
          nil -> Map.put(map, actor_id, [event])
          arr -> Map.put(map, actor_id, [event | arr])
        end
      end)

    events_by_actor
  end

  def send_message(message \\ "hello") do
    HTTPoison.post!(System.get_env("SLACK_WEBHOOK_URL"), "{\"text\": \"#{message}\" }")
  end
end
