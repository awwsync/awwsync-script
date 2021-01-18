defmodule AWWSYNC do
  @moduledoc """
  Documentation for `AWWSYNC`.
  """
  @secs_per_day 86400

  @doc """
  Hello world.

  ## Examples

      iex> AWWSYNC.hello()
      :world

  """
  def generate_doc do
  end

  def get_since_date() do
    {:ok, datetime} = DateTime.now("Etc/UTC")

    DateTime.add(datetime, -@secs_per_day)
  end
end
