defmodule Github do
  @client Tentacat.Client.new(%{access_token: System.get_env("GITHUB_ACCESS_TOKEN", "")})
  @watched_events [
    "closed",
    "commented",
    "committed",
    "convert_to_draft",
    "cross-referenced",
    "mentioned",
    "merged",
    "ready_for_review",
    "reopened",
    "review_requested",
    "reviewed"
  ]

  def get_events(since_date) do
    {response, _pagination_url, _client_auth} =
      Tentacat.Issues.Events.list_all(@client, "facebook", "react")

    # IO.inspect(response)
    # IO.inspect(daresta)
    # IO.inspect(client)

    {200, data, _response} = response
    IO.inspect(data)
  end

  def parse_events(events) do
    events
  end
end
