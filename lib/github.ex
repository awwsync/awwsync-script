defmodule Github do
  @client Tentacat.Client.new(%{access_token: System.get_env("GITHUB_ACCESS_TOKEN", "")})

  def get_events() do
    {response, data, client} = Tentacat.Issues.Events.list_all(@client, "facebook", "react")

    # parse_events(data)
  end

  def parse_events(events) do
    events
  end
end
