defmodule Runner do
  @secs_per_day 86400

  def generate_doc do
    Events.Github.get_merged_prs("facebook", "react", get_since_date())
    |> Slack.prepare_message()
    |> Slack.send_message()
  end

  @spec get_since_date :: DateTime.t()
  def get_since_date() do
    {:ok, datetime} = DateTime.now("Etc/UTC")

    DateTime.add(datetime, -@secs_per_day * 7)
  end
end