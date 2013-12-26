##
# Class with methods related to managing resque schedules.

class ScheduleManager

  ##
  # For each feed in the database, ensure that resque-schedule has a scheduled update for the feed.
  #
  # If a feed is found with no scheduled update, a job is scheduled to update the feed periodically.
  #
  # After invoking this method all feeds have scheduled updates that run every hour.
  #
  # Note.- This methods relies on the schedule to run updates for a feed being named "update_feed_#{feed.id}". If this
  # naming scheme ever changes, this method will have to be changed accordingly.

  def self.fix_update_schedules
    Rails.logger.debug 'Fixing feed update schedules'
    feeds_unscheduled = []

    Feed.all.each do |feed|
      # get update schedule for the feed
      schedule = Resque.get_schedule "update_feed_#{feed.id}"
      Rails.logger.debug "Update schedule for feed #{feed.id}  #{feed.title}: #{schedule}"
      # if a feed has no update schedule, add it to the array
      if schedule == nil
        Rails.logger.warn "Missing schedule for feed #{feed.id} - #{feed.title}"
        feeds_unscheduled << feed
      end
    end

    if feeds_unscheduled.length > 0
      Rails.logger.warn "A total of #{feeds_unscheduled.length} feeds are missing their update schedules. Adding missing schedules."
      feeds_unscheduled.each do |feed|
        Rails.logger.warn "Adding missing update schedule for feed #{feed.id} - #{feed.title}"
        schedule_feed_updates feed.id
      end
    end
  end

  ##
  # Schedule updating of a feed using Resque-scheduler.
  # Receives as argument the id of the feed which update is to be scheduled.
  #
  # There can only be one scheduled job for updates of a given feed. If there is a scheduled update
  # job for a feed and this method is invoked with the id of that feed, the old schedule is updated.
  #
  # Scheduled jobs are named "update_feed_[feed_id]", they can be monitored using the Resque web console.
  #
  # The first run of a job is scheduled to happen a random amount of minutes, between 0 and 60, after this
  # method is invoked. After that the job is run every hour. This is done so that feed updates are more or less
  # evenly, or at least randomly, spaced in time. This way the server load from the updates is spaced over
  # time, to affect user experience as little as possible.

  def self.schedule_feed_updates(feed_id)
    delay = Random.rand 61
    Rails.logger.info "Scheduling updates of feed #{feed_id} every hour, starting #{delay} minutes from now at #{Time.now + delay.minutes}"
    name = "update_feed_#{feed_id}"
    config = {}
    config[:class] = 'UpdateFeedJob'
    config[:args] = feed_id
    config[:every] = ['1h', {first_in: delay.minutes}]
    Resque.set_schedule name, config
  end

  ##
  # Unschedule (this is, remove from scheduling) the update feed job for the passed feed.
  # Receives as argument the id of the feed which update is to be unscheduled.
  #
  # After invoking this method, an update job for this feed will never be enqueued again (at least while
  # schedule_feed_updates is not invoked again for this feed).

  def self.unschedule_feed_updates(feed_id)
    Rails.logger.info "Unscheduling updates of feed #{feed_id}"
    Resque.remove_schedule "update_feed_#{feed_id}"
  end
end