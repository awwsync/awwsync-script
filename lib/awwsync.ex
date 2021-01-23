defmodule AWWSYNC do
  @secs_per_day 86400

  def generate_doc do
    get_since_date() |> Github.get_events()
  end

  @spec get_since_date :: DateTime.t()
  def get_since_date() do
    {:ok, datetime} = DateTime.now("Etc/UTC")

    DateTime.add(datetime, -@secs_per_day)
  end
end
