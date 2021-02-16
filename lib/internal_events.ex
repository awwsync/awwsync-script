defmodule InternalEvents do
  @moduledoc """
  This module is responsible for converting events from different platform to fit the internal event type
  """

  @type awwsync_event :: %{
          required(:actor) => any,
          required(:event_type) => String.t(),
          required(:subject) => any,
          optional(:event_payload) => any
        }

  def release_to_an_event(release) do
  end

  def merged_pr_to_an_event(pr) do
  end

  def timeline_event_to_an_event(event) do
  end
end
