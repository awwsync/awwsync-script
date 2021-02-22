defmodule Runner do
  def generate_doc do
    Events.Github.get_issues_with_timeline_events(
      "facebook",
      "react",
      Utils.Dates.get_date_x_days_ago(1)
    )
    |> Slack.prepare_message()
    |> Slack.send_message()
  end
end
