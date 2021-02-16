defmodule Events.Internal do
  @moduledoc """
  This module is responsible for converting events from different platform to fit the internal event type
  """

  @type awwsync_event :: %{
          required(:actor) => any,
          required(:event_type) => String.t(),
          required(:subject) => any,
          optional(:event_payload) => any
        }
end
