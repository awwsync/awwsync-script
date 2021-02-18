defmodule Events.AwwSync do
  @moduledoc """
  This module is responsible for converting events from different platform to fit the internal event type
  """

  defstruct actor: nil, event_type: nil, subject: nil, event_payload: nil, platform: nil

  @type t :: %__MODULE__{
          actor: any,
          event_type: String.t(),
          subject: any,
          event_payload: any | nil,
          platform: String.t()
        }
end
