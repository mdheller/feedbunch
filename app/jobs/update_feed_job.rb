require 'subscriptions_manager'
require 'schedule_manager'

##
# Background job to fetch and update a feed's entries.
#
# Its perform method will be invoked from a Resque worker.

class UpdateFeedJob
  @queue = :update_feeds

  ##
  # Fetch and update entries for the passed feed.
  # Receives as argument the id of the feed to be fetched.
  #
  # If the feed does not exist, further refreshes of the feed are unscheduled. This avoids the case
  # in which scheduled updates for a deleted feed happened periodically.
  #
  # Every time a feed update runs the unread entries count for each subscribed user are recalculated and corrected if necessary
  #
  # This method is intended to be invoked from Resque, which means it is performed in the background.

  def self.perform(feed_id)
    # Check that feed actually exists
    if !Feed.exists? feed_id
      Rails.logger.warn "Feed #{feed_id} scheduled to be updated, but it does not exist in the database. Unscheduling further updates."
      ScheduleManager.unschedule_feed_updates feed_id
      return
    end
    feed = Feed.find feed_id

    # Fetch feed
    FeedClient.fetch feed, false if Feed.exists? feed_id

    # Update unread entries count for all subscribed users.
    feed.users.each do |user|
      SubscriptionsManager.recalculate_unread_count feed, user
    end
  end
end