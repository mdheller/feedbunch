require 'spec_helper'

describe 'unread entries count' do

  before :each do
    # Ensure no actual HTTP calls are made
    RestClient.stub get: true

    @user = FactoryGirl.create :user

    @folder1 = FactoryGirl.build :folder, user_id: @user.id
    @user.folders << @folder1

    @feed1 = FactoryGirl.create :feed
    @feed2 = FactoryGirl.create :feed
    @user.feeds << @feed1 << @feed2
    @folder1.feeds << @feed1

    @entry1_1 = FactoryGirl.build :entry, feed_id: @feed1.id
    @entry1_2 = FactoryGirl.build :entry, feed_id: @feed1.id
    @entry1_3 = FactoryGirl.build :entry, feed_id: @feed1.id
    @entry2_1 = FactoryGirl.build :entry, feed_id: @feed2.id
    @feed1.entries << @entry1_1 << @entry1_2 << @entry1_3
    @feed2.entries << @entry2_1

    login_user_for_feature @user
    visit feeds_path
  end

  it 'shows total number of unread entries', js: true do
    unread_folder_entries_should_eq 'all', 4
  end

  it 'shows number of unread entries in a folder', js: true do
    unread_folder_entries_should_eq @folder1.id, 3
  end

  it 'shows number of unread entries in a single feed', js: true do
    unread_feed_entries_should_eq @feed1.title, 3
    unread_feed_entries_should_eq @feed2.title, 1
  end

  it 'updates number of unread entries when clicking on a folder'

  it 'updates number of unread entries when clicking on a feed'

  it 'updates number of unread entries when adding a feed to a newly created folder', js: true do
    @folder1.feeds << @feed2
    visit feeds_path
    title = 'New folder'
    add_feed_to_new_folder @feed1.id, title

    # Entry count in @folder1 should be updated
    unread_folder_entries_should_eq @folder1.id, 1

    # new folder should have the correct entry count
    new_folder = Folder.where(user_id: @user.id, title: title).first
    unread_folder_entries_should_eq new_folder.id, 3
  end

  it 'shows number of unread entries in a newly subscribed feed'

  it 'updates number of unread entries when moving a feed into a folder'

  it 'updates number of unread entries when removing a feed from a folder'

  it 'updates number of unread entries when unsubscribing from a feed'

  it 'updates number of unread entries when refreshing a feed'
end