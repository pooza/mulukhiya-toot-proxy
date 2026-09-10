require 'rss'

module Mulukhiya
  # `feed_entry` の全キーが RSS 2.0 の item に通ること (#4639)。
  #
  # ⚠⚠ **`Ginseng::Web::RSS20FeedRenderer` はキーをすべて item のセッターとして送る**
  # （`entry.each {|k, v| item.send(:"#{k}=", v)}`）。**item に無いキーを 1 つでも
  # 混ぜると例外になり、その後ろのキーが全部捨てられる。**
  #
  # 🔴 `created_at:` が混ざっていて、**`/feed/media` の全 item から `<pubDate>` が
  # 消え、item ごとに error 行が出ていた**。media_catalog は 5.23.0 から既定で無効
  # だったので誰も踏まず、#4639 の Gate 2 の手順 3（dev26 で flip）で初めて出た。
  #
  # ⚠ `feed_entry` は DB の添付を引くので、ここでは**同じ形のハッシュ**を
  # `AttachmentMethods#feed_entry` から組み立てて検証する（DB 非依存）。
  class MediaFeedEntryTest < TestCase
    # `feed_entry` が参照するものだけを持つダブル。
    class AttachmentDouble
      include AttachmentMethods

      def uri = Ginseng::URI.parse('https://example.com/media/a.webp')
      def name = 'a.webp'
      def size_str = '2KiB'
      def description = nil
      def account = Struct.new(:display_name).new('admin')
      def date = Time.parse('2026-07-11T09:13:51+09:00')
    end

    def setup
      @entry = AttachmentDouble.new.feed_entry
    end

    # 🔴 **本体。**全キーが item のセッターとして通る（例外にならない）。
    def test_every_key_is_an_rss_item_setter
      item = new_item

      @entry.each_key do |key|
        assert_respond_to(item, :"#{key}=", "RSS item に #{key}= が無い（後続のキーが捨てられる）")
      end
    end

    # 🔴 **`<pubDate>` が出る。**`created_at` で例外になると、ここが丸ごと消えていた。
    def test_rendered_item_has_a_pub_date
      xml = render([@entry])

      assert_match(%r{<pubDate>.+</pubDate>}, xml, 'pubDate が出ていない')
      assert_match(%r{<title>a\.webp \(2KiB\)</title>}, xml)
    end

    # ⚠ **退行の目印。**`created_at` を戻したら落ちる。
    def test_created_at_is_not_in_the_entry
      refute(@entry.key?(:created_at), 'created_at が戻っている（RSS item に created_at= は無い）')
    end

    private

    def new_item
      item = nil
      RSS::Maker.make('rss2.0') do |maker|
        maker.channel.title = 't'
        maker.channel.link = 'https://example.com/'
        maker.channel.description = 'd'
        maker.items.new_item {|i| item = i}
      end
      return item
    end

    # `RSS20FeedRenderer#feed` と同じ流儀（キーをすべてセッターとして送る）で組み立てる。
    def render(entries)
      return RSS::Maker.make('rss2.0') do |maker|
        maker.channel.title = 't'
        maker.channel.link = 'https://example.com/'
        maker.channel.description = 'd'
        entries.each do |entry|
          maker.items.new_item do |item|
            entry.each {|k, v| item.send(:"#{k}=", v)}
          end
        end
      end.to_s
    end
  end
end
