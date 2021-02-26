defmodule Events.Github.Descriptions do
  def get_event_description(%{:event_type => event_type} = awwsync_event)
      when event_type == "issue_comment" do
    %{:actor => actor, :subject => subject} = awwsync_event

    message = "#{actor["login"]} Left a comment for <#{subject.url}|#{subject.name}>"

    message
  end

  def get_event_description(%{:event_type => event_type} = awwsync_event)
      when event_type == "pr_review" do
    %{:actor => actor, :subject => subject} = awwsync_event

    message = "#{actor["login"]} Left a review for <#{subject.url}|#{subject.name}>"

    message
  end

  def get_event_description(%{:event_type => event_type} = awwsync_event)
      when event_type == "issue_closed" do
    %{:actor => actor, :subject => subject} = awwsync_event

    message = "#{actor["login"]} Closed issue <#{subject.url}|#{subject.name}>"

    message
  end

  def get_event_description(%{:event_type => event_type} = awwsync_event)
      when event_type == "review_request" do
    %{
      :actor => actor,
      :subject => subject,
      :event_payload => %{:requested_reviewer => requested_reviewer}
    } = awwsync_event

    message =
      "#{actor["login"]} Requested a review from #{requested_reviewer["login"]} for <#{
        subject.url
      }|#{subject.name}>"

    message
  end

  def get_event_description(%{:event_type => event_type} = awwsync_event)
      when event_type == "commit" do
    %{:actor => actor, :subject => subject} = awwsync_event

    message = "#{actor["login"]} pushed a commit in <#{subject.url}|#{subject.name}>"

    message
  end

  def get_event_description(%{:event_type => event_type} = awwsync_event)
      when event_type == "merged_pr" do
    %{:actor => actor, :subject => subject} = awwsync_event

    message = "#{actor["login"]} Merged <#{subject.url}|#{subject.name}>"

    message
  end

  def get_event_description(%{:event_type => event_type} = awwsync_event)
      when event_type == "release" do
    %{:actor => actor, :subject => subject} = awwsync_event

    message = "#{actor["login"]} rolled a new release: <#{subject.url}|#{subject.name}>"

    message
  end

  def get_event_description(%{:event_type => event_type} = awwsync_event)
      when event_type == "new_issue" do
    %{:actor => actor, :subject => subject} = awwsync_event

    message = "#{actor["login"]} Created a new issue <#{subject.url}|#{subject.name}>"

    message
  end
end
