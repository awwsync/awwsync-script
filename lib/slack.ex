defmodule Slack do
  def prepare_message(events) do
  end

  def send_message(message \\ "hello") do
    HTTPoison.post!(System.get_env("SLACK_WEBHOOK_URL"), "{\"text\": \"#{message}\" }")
  end
end
