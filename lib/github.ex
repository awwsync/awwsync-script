defmodule Github do
  @client Tentacat.Client.new(%{access_token: System.get_env("GITHUB_ACCESS_TOKEN", "")})

  def get_events() do
    Tentacat.Issues.Events.list_all(@client, "facebook", "react")
  end
end
