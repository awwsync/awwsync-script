defmodule Utils.Dates do
  @secs_per_day 86400

  @spec get_date_x_days_ago(number()) :: DateTime.t()
  def get_date_x_days_ago(days \\ 1) do
    {:ok, datetime} = DateTime.now("Etc/UTC")

    DateTime.add(datetime, -@secs_per_day * days)
  end

  @spec is_date_gt_or_eq(String.t(), DateTime.t()) :: boolean
  def is_date_gt_or_eq(date, comparable_dt) do
    {:ok, dt_date, _offset} = DateTime.from_iso8601(date)

    case DateTime.compare(dt_date, comparable_dt) do
      res when res in [:gt, :eq] -> true
      _ -> false
    end
  end
end
