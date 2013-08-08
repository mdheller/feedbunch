require 'folder_feed_remove'
require 'folder_feed_add'
require 'feed_subscriber'
require 'feed_refresh'
require 'entry_state_change'
require 'entry_recovery'
require 'subscriptions_importer'
require 'subscriptions_manager'

##
# User model. Each instance of this class represents a single user that can log in to the application
# (or at least that has passed through the signup process but has not yet confirmed his email).
#
# This class has been created by installing the Devise[https://github.com/plataformatec/devise] gem and
# running the following commands:
#   rails generate devise:install
#   rails generate devise User
#
# The Devise[https://github.com/plataformatec/devise] gem manages authentication in this application. To
# learn more about Devise visit:
# {https://github.com/plataformatec/devise}[https://github.com/plataformatec/devise]
#
# Beyond the attributes added to this class by Devise[https://github.com/plataformatec/devise] for authentication,
# Feedbunch establishes relationships between the User model and the following models:
#
# - FeedSubscription: Each user can be subscribed to many feeds, but a single subscription belongs to a single user (one-to-many relationship).
# - Feed, through the FeedSubscription model: This enables us to retrieve the feeds a user is subscribed to.
# - Folder: Each user can have many folders and each folder belongs to a single user (one-to-many relationship).
# - Entry, through the Feed model: This enables us to retrieve all entries for all feeds a user is subscribed to.
# - EntryState: This enables us to retrieve the state (read or unread) of all entries for all feeds a user is subscribed to.
#
# Also, the User model has the following attributes:
#
# - Admin: Boolean that indicates whether the user is an administrator. This attribute is used to restrict access to certain
# functionality, like Resque administration.
#
# When a user is subscribed to a feed (this is, when a feed is added to the user.feeds array), EntryState instances
# are saved to mark all its entries as unread for this user.
#
# Conversely when a user unsubscribes from a feed (this is, when a feed is removed from the user.feeds array), all
# EntryState instances for its entries and for this user are deleted; the app does not store read/unread state for
# entries that belong to feeds to which the user is not subscribed.
#
# It is not mandatory that a user be suscribed to any feeds (in fact when a user first signs up he won't
# have any suscriptions).

class User < ActiveRecord::Base

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable, :timeoutable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me

  has_many :feed_subscriptions, dependent: :destroy, uniq: true,
           after_add: :mark_unread_entries,
           before_remove: :before_remove_feed_subscription,
           after_remove: :removed_feed_subscription
  has_many :feeds, through: :feed_subscriptions
  has_many :folders, dependent: :destroy, uniq: true
  has_many :entries, through: :feeds
  has_many :entry_states, dependent: :destroy, uniq: true
  has_one :data_import, dependent: :destroy

  before_save :encode_password

  ##
  # Retrieve entries from a feed. See EntryRecovery#feed_entries

  def feed_entries(feed_id, include_read=false)
    EntryRecovery.feed_entries feed_id, include_read, self
  end

  ##
  # Retrieve unread entries from a folder. See EntryRecovery#feed_entries

  def unread_folder_entries(folder_id)
    EntryRecovery.unread_folder_entries folder_id, self
  end

  ##
  # Retrieve the number of unread entries in a feed for this user.
  # See SubscriptionsManager#unread_feed_entries_count

  def feed_unread_count(feed)
    SubscriptionsManager.feed_unread_count feed, self
  end

  ##
  # Retrieve the number of unread entries in a folder for this user.
  # See SubscriptionsManager#unread_folder_entries_count

  def folder_unread_count(feed)
    SubscriptionsManager.folder_unread_count feed, self
  end

  ##
  # Remove a feed from a folder. See FolderFeedRemove#remove_feed_from_folder

  def remove_feed_from_folder(feed_id)
    FolderFeedRemove.remove_feed_from_folder feed_id, self
  end

  ##
  # Add a feed to an existing folder. See FolderFeedAdd#add_feed_to_folder

  def add_feed_to_folder(feed_id, folder_id)
    FolderFeedAdd.add_feed_to_folder feed_id, folder_id, self
  end

  ##
  # Add a feed to a new folder. See FolderFeedAdd#add_feed_to_new_folder

  def add_feed_to_new_folder(feed_id, folder_title)
    FolderFeedAdd.add_feed_to_new_folder feed_id, folder_title, self
  end

  ##
  # Refresh a single feed. See FeedRefresh#refresh_feed

  def refresh_feed(feed_id)
    FeedRefresh.refresh_feed feed_id, self
  end

  ##
  # Subscribe to a feed. See FeedSubscriber#subscribe

  def subscribe(url)
    FeedSubscriber.subscribe url, self
  end

  ##
  # Unsubscribe from a feed. See FeedUnsubscriber#unsubscribe

  def unsubscribe(feed)
    SubscriptionsManager.remove_subscription feed, self
  end

  ##
  # Change the read/unread state of an array of entries for this user. See EntryStateChange#change_entry_state

  def change_entry_state(entry_ids, state)
    EntryStateChange.change_entry_state entry_ids, state, self
  end

  ##
  # Import an OPML (optionally zipped) with subscription data, and subscribe the user to the feeds
  # in it. See SubscriptionsImporter#import_subscriptions

  def import_subscriptions(file)
    SubscriptionsImporter.import_subscriptions file, self
  end

  private

  ##
  # Before saving a user instance, ensure the encrypted_password is encoded as utf-8

  def encode_password
    self.encrypted_password.encode! 'utf-8'
  end

  ##
  # Mark as unread for this user all entries of the feed passed as argument.

  def mark_unread_entries(feed_subscription)
    feed = feed_subscription.feed
    feed.entries.each do |entry|
      if !EntryState.exists? user_id: self.id, entry_id: entry.id
        entry_state = self.entry_states.build read: false
        entry_state.entry_id = entry.id
        entry_state.save!
      end
    end
  end

  ##
  # Before removing a feed subscription:
  # - remove the feed from its current folder, if any. If this means the folder is now empty, a deletion of the folder is triggered.
  # - delete all state information (read/unread) for this user and for all entries of the feed.

  def before_remove_feed_subscription(feed_subscription)
    feed = feed_subscription.feed

    folder = feed.user_folder self
    folder.feeds.delete feed if folder.present?

    remove_entry_states feed
  end

  ##
  # When a feed is removed from a user's subscriptions, check if there are other users still subscribed to the feed
  # and if there are no subscribed users, delete the feed. This triggers the deletion of all its entries and entry-states.

  def removed_feed_subscription(feed_subscription)
    feed = feed_subscription.feed
    if feed.users.blank?
      Rails.logger.warn "no more users subscribed to feed #{feed.id} - #{feed.fetch_url} . Removing it from the database"
      feed.destroy
    end
  end

  ##
  # Remove al read/unread entry information for this user, for all entries of the feed passed as argument.

  def remove_entry_states(feed)
    feed.entries.each do |entry|
      entry_state = EntryState.where(user_id: self.id, entry_id: entry.id).first
      self.entry_states.delete entry_state
    end
  end

end
