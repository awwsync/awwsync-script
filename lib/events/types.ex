defmodule Events.Types do
  defmacro __using__(_opts) do
    quote do
      @type awwsync_event :: %{
              required(:actor) => any,
              required(:event_type) => String.t(),
              required(:subject) => any,
              optional(:event_payload) => any
            }
    end
  end
end
