require 'spec_helper'

describe FeedClient do
  before :each do
    published = Time.zone.parse('2000-01-01')
    ActiveSupport::TimeZone.any_instance.stub(:now).and_return published

    @feed = FactoryGirl.create :feed, title: 'Some feed title', url: 'http://some.feed.com'

    @feed_title = 'CRISEI'
    @feed_url = 'http://crisei.blogalia.com/'

    @entry1 = FactoryGirl.build :entry
    @entry1.title = 'SIR GAWAIN: GALLARDO Y CALAVERA'
    @entry1.url = 'http://crisei.blogalia.com//historias/74112'
    @entry1.summary = '<p>Hijo de reina hada, aunque el detalle pase por alto en la saga, sobrino del rey Arturo y hermanastro a su pesar del traidor Mordred, escocés de isla pero latino de corazón, el jovial Sir Gawain es el personaje que, sin ser familia directa de Valiente, se convierte en la serie en lo más parecido a un padre, primero, a un hermano mayor, más tarde, y en ocasiones incluso a un atolondrado hermano pequeño.</p>'
    @entry1.published = published
    @entry1.guid = 'http://crisei.blogalia.com//historias/74112'

    @entry2 = FactoryGirl.build :entry
    @entry2.title = 'PRÍNCIPE VALIENTE: NUEVA EDICIÓN GIGANTE Y EN COLOR'
    @entry2.url = 'http://crisei.blogalia.com//historias/74115'
    @entry2.summary = '<p>Nueva edición restaurada, y a color, de Príncipe Valiente. A partir de la restauración en blanco y negro de Manuel Caldas y con los colores originales reconstruidos, pero no a partir de los viejos periódicos escaneados.</p>'
    @entry1.published = published
    @entry2.guid = 'http://crisei.blogalia.com//historias/74115'
  end

  context 'ISO-8859-1 encoded feed fetching' do

    before :each do
      feed_file = File.join __dir__, '..', '..', '..', 'attachments', 'iso-8859-1-feed.xml'
      feed_xml = File.read feed_file
      feed_xml.stub(:headers).and_return({})
      RestClient.stub get: feed_xml
    end

    it 'returns the feed if successful' do
      feed = FeedClient.fetch @feed
      feed.should eq @feed
    end

    it 'fetches the right entries and saves them in the database' do
      FeedClient.fetch @feed
      @feed.reload
      @feed.entries.count.should eq 2

      entry1 = @feed.entries[0]
      entry1.title.should eq @entry1.title
      entry1.url.should eq @entry1.url
      entry1.author.should eq @entry1.author
      entry1.summary.should eq CGI.unescapeHTML(@entry1.summary)
      entry1.published.should eq @entry1.published
      entry1.guid.should eq @entry1.guid

      entry2 = @feed.entries[1]
      entry2.title.should eq @entry2.title
      entry2.url.should eq @entry2.url
      entry2.author.should eq @entry2.author
      entry2.summary.should eq CGI.unescapeHTML(@entry2.summary)
      entry2.published.should eq @entry2.published
      entry2.guid.should eq @entry2.guid
    end

    it 'ignores entry if it is received again' do
      # Create an entry for feed @feed with the same guid as @entry1 (which is not saved in the DB) but all other
      # fields with different values
      entry_before = FactoryGirl.create :entry, feed_id: @feed.id, title: 'Original title',
                                        url: 'http://original.url.com', author: 'Original author',
                                        content: 'Original content', summary: 'Original summary',
                                        published: Time.zone.parse('2013-01-01T00:00:00'), guid: @entry1.guid

      # XML that will be fetched contains an entry with the same guid. It will be ignored
      FeedClient.fetch @feed

      # After fetching, entry should be unchanged
      entry_after = Entry.where(guid: entry_before.guid, feed_id: entry_before.feed_id).first
      entry_after.feed_id.should eq entry_before.feed_id
      entry_after.title.should eq entry_before.title
      entry_after.url.should eq entry_before.url
      entry_after.author.should eq entry_before.author
      entry_after.summary.should eq CGI.unescapeHTML(entry_before.summary)
      entry_after.guid.should eq entry_before.guid
      entry_after.published.should eq entry_before.published
    end

    it 'saves entry if another one with the same guid but from a different feed is already in the database' do
      feed2 = FactoryGirl.create :feed
      # Create an entry for feed feed2 with the same guid as @entry1 (which is not saved in the DB) but all other
      # fields with different values
      entry = FactoryGirl.create :entry, feed_id: feed2.id, title: 'Original title',
                                 url: 'http://origina.url.com', author: 'Original author',
                                 content: 'Original content', summary: '<p>Original summary</p>',
                                 published: Time.zone.parse('2013-01-01T00:00:00'),
                                 guid: @entry1.guid

      # XML that will be fetched contains an entry with the same guid but different feed. Both entries
      # should be treated as different entities.
      FeedClient.fetch @feed

      # After fetching, entry should remain untouched
      entry.reload
      entry.feed_id.should eq feed2.id
      entry.title.should eq 'Original title'
      entry.url.should eq 'http://origina.url.com'
      entry.author.should eq 'Original author'
      entry.summary.should eq '<p>Original summary</p>'
      entry.published.should eq Time.zone.parse('2013-01-01T00:00:00')
      entry.guid.should eq @entry1.guid

      # the fetched entry should be saved in the database as well
      fetched_entry = Entry.where(guid: @entry1.guid, feed_id: @feed.id).first
      fetched_entry.feed_id.should eq @feed.id
      fetched_entry.title.should eq @entry1.title
      fetched_entry.url.should eq @entry1.url
      fetched_entry.author.should eq @entry1.author
      fetched_entry.summary.should eq CGI.unescapeHTML(@entry1.summary)
      fetched_entry.published.should eq @entry1.published
      fetched_entry.guid.should eq @entry1.guid
    end

    it 'retrieves the feed title and saves it in the database' do
      FeedClient.fetch @feed
      @feed.reload
      @feed.title.should eq @feed_title
    end

    it 'retrieves the feed URL and saves it in the database' do
      FeedClient.fetch @feed
      @feed.reload
      @feed.url.should eq @feed_url
    end
  end

  context 'RSS 2.0 feed autodiscovery' do

    it 'updates fetch_url of the feed with autodiscovery full URL' do
      feed_url = 'http://webpage.com/feed'
      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/rss+xml" href="#{feed_url}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      # First fetch the webpage; then, when fetching the actual feed URL, simulate receiving a 304-Not Modified
      RestClient.stub :get do |url|
        if url==feed_url
          raise RestClient::NotModified.new
        else
          webpage_html
        end
      end

      @feed.fetch_url.should_not eq feed_url
      FeedClient.fetch @feed, true
      @feed.reload
      @feed.fetch_url.should eq feed_url
    end

    it 'updates fetch_url of the feed with autodiscovery relative URL' do
      feed_fetch_url = 'http://webpage.com/feed'
      feed_path = '/feed'
      feed_url = 'http://webpage.com'
      feed = FactoryGirl.create :feed, title: feed_url, fetch_url: feed_url

      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/rss+xml" href="#{feed_path}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      # First fetch the webpage; then, when fetching the actual feed URL, simulate receiving a 304-Not Modified
      RestClient.stub :get do |url|
        if url==feed_fetch_url
          raise RestClient::NotModified.new
        else
          webpage_html
        end
      end

      feed.fetch_url.should_not eq feed_fetch_url
      FeedClient.fetch feed, true
      feed.reload
      feed.fetch_url.should eq feed_fetch_url
    end

    it 'fetches feed' do
      feed_url = 'http://webpage.com/feed'
      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/rss+xml" href="#{feed_url}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      feed_xml = <<FEED_XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <title>#{@feed_title}</title>
    <link>#{@feed_url}</link>
    <description>xkcd.com: A webcomic of romance and math humor.</description>
    <language>en</language>
    <item>
      <title>#{@entry1.title}</title>
      <link>#{@entry1.url}</link>
      <description>#{@entry1.summary}</description>
      <pubDate>#{@entry1.published}</pubDate>
      <guid>#{@entry1.guid}</guid>
    </item>
  </channel>
</rss>
FEED_XML
      feed_xml.stub headers: {}

      # First fetch the webpage; then, when fetching the actual feed URL, return an RSS 2.0 XML with one entry
      RestClient.stub :get do |url|
        if url==feed_url
          feed_xml
        else
          webpage_html
        end
      end

      @feed.entries.should be_blank
      FeedClient.fetch @feed, true
      @feed.entries.count.should eq 1
      @feed.entries.where(guid: @entry1.guid).should be_present
    end

    it 'detects that autodiscovered feed is already in the database' do
      feed_url = 'http://webpage.com/feed'
      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/rss+xml" href="#{feed_url}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      feed_xml = <<FEED_XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <title>#{@feed_title}</title>
    <link>#{@feed_url}</link>
    <description>xkcd.com: A webcomic of romance and math humor.</description>
    <language>en</language>
    <item>
      <title>#{@entry1.title}</title>
      <link>#{@entry1.url}</link>
      <description>#{@entry1.summary}</description>
      <pubDate>#{@entry1.published}</pubDate>
      <guid>#{@entry1.guid}</guid>
    </item>
  </channel>
</rss>
FEED_XML
      feed_xml.stub headers: {}

      old_feed = FactoryGirl.create :feed, fetch_url: feed_url
      new_feed = FactoryGirl.create :feed

      # First fetch the webpage; then, when fetching the actual feed URL, return an Atom XML with one entry
      RestClient.stub :get do |url|
        if url==feed_url
          feed_xml
        elsif url==new_feed.fetch_url
          webpage_html
        end
      end

      old_feed.entries.should be_blank

      FeedClient.fetch new_feed, true

      # When performing autodiscovery, FeedClient should realise that there is another feed in the database with
      # the autodiscovered fetch_url; it should delete the "new" feed and instead fetch and return the "old" one
      old_feed.entries.count.should eq 1
      old_feed.entries.where(guid: @entry1.guid).should be_present
      Feed.exists?(new_feed).should be false
    end

    it 'uses first feed available for autodiscovery' do
      rss_url = 'http://webpage.com/rss'
      atom_url = 'http://webpage.com/atom'
      feed_url = 'http://webpage.com/feed'
      webpage_html = <<WEBPAGE_HTML
<!DOCTYPE html>
<html>
<head>
  <link rel="alternate" type="application/rss+xml" href="#{rss_url}">
  <link rel="alternate" type="application/atom+xml" href="#{atom_url}">
  <link rel="feed" href="#{feed_url}">
</head>
<body>
  webpage body
</body>
</html>
WEBPAGE_HTML
      webpage_html.stub headers: {}

      webpage_url = @feed.fetch_url
      # First fetch the webpage; then, when fetching the actual feed URL, simulate receiving a 304-Not Modified
      RestClient.stub :get do |url|
        if url==webpage_url
          webpage_html
        else
          raise RestClient::NotModified.new

        end
      end

      @feed.fetch_url.should_not eq rss_url
      FeedClient.fetch @feed, true
      @feed.reload
      @feed.fetch_url.should eq rss_url
    end

  end

end