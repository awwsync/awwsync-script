defmodule Github do
  @client Tentacat.Client.new()

  def get_events() do
    Tentacat.Issues.Events.list_all(@client, "awwsync", "awwsync-script")
  end
end
