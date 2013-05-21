##
# Controller to access the Feed model.

class FeedsController < ApplicationController
  before_filter :authenticate_user!

  respond_to :html

  ##
  # list all feeds the currently authenticated is suscribed to

  def index
    @feeds = current_user.feeds
    @folders = current_user.folders
    respond_with @feeds, @folders
  rescue => e
    handle_error e
  end

  ##
  # Return HTML with all entries for a given feed, as long as the currently authenticated user is suscribed to it.
  #
  # If the requests asks for a feed the current user is not suscribed to, the response is a 404 error code (Not Found).

  def show
    @entries = current_user.unread_feed_entries params[:id]

    if @entries.present?
      respond_with @entries, layout: false
    else
      Rails.logger.warn "Feed #{params[:id]} has no entries, returning a 404"
      head status: 404
    end

    return
  rescue => e
    handle_error e
  end

  ##
  # Fetch a feed and save in the database any new entries, as long as the currently authenticated user is suscribed to it.
  #
  # After that it does exactly the same as the show action: return HTML with all entries for the feed.
  #
  # If the request asks to refresh a folder the user is not suscribed to, the response is a 404 error code (Not Found).

  def refresh
    @entries = current_user.refresh_feed params[:id]
    if @entries.present?
      respond_with @entries, template: 'feeds/show', layout: false
    else
      Rails.logger.warn "Feed #{params[:id]} has no entries, returning a 404"
      head status: 404
    end

  rescue => e
    handle_error e
  end

  ##
  # Subscribe the authenticated user to the feed passed in the params[:subscribe][:rss] param.
  # If successful, return JSON containing HTML with the entries of the feed.

  def create
    url = params[:subscription][:rss]
    @feed = current_user.subscribe url

    if @feed.present?
      respond_with @feed, layout: false
    else
      Rails.logger.error "Could not subscribe user #{current_user.id} to feed #{feed_url}, returning a 404"
      #TODO respond with html for search results, for instance with head status:300 (Multiple Choices)
      head status: 404
    end

  rescue => e
    handle_error e
  end

  ##
  # Unsubscribe the authenticated user from the feed passed in the params[:id] param.
  #
  # Return status:
  # - 204 if the feed was in a folder, and it still has feeds
  # - 205 if the feed was in a folder which has been deleted because it had no more feeds

  def destroy
    deleted_folder = current_user.unsubscribe params[:id]
    if deleted_folder.present?
      head status: 205
    else
      head status: 204
    end
  rescue => e
    handle_error e
  end

  private

  ##
  # Handle an error raised during action processing.
  # It just logs the error and returns an HTTP 500 or 404 error, depending
  # on the kind of error raised.

  def handle_error(error)
    if error.is_a? ActiveRecord::RecordNotFound
      head status: 404
    elsif error.is_a? AlreadySubscribedError
      # If user is already subscribed to the feed, return 304
      head status: 304
    else
      Rails.logger.error error.message
      Rails.logger.error error.backtrace
      head status: 500
    end
  end
end
