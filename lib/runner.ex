defmodule Runner do
  def generate_doc do
    Events.Github.get_events(
      "gnosis",
      "safe-react",
      Utils.Dates.get_date_x_days_ago(1),
      [~r/bot/]
    )
    |> Slack.prepare_message()
    |> Slack.send_message()
  end
end
