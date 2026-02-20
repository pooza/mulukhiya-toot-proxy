module Mulukhiya
  class AttachmentTest < TestCase
    def disable?
      return true unless Environment.dbms_class&.config?
      return super
    end

    def setup
      @attachment = attachment_class[attachment_class.catalog.first[:id]]
    end

    test 'テスト用メディアファイルの有無' do
      assert_not_nil(@attachment)
    end

    def test_to_h
      return unless @attachment
      h = @attachment.to_h

      assert(h.key?(:id))
      assert_kind_of(Hash, h)
      assert_kind_of([String, NilClass], h[:created_at])
      assert_kind_of([Float, NilClass], h[:duration])
      assert_kind_of(String, h[:file_name])
      assert_kind_of(String, h[:file_size_str])
      assert_kind_of(String, h[:mediatype])
      assert_kind_of([String, NilClass], h[:pixel_size])
      assert_kind_of([String, NilClass], h[:thumbnail_url])
      assert_kind_of(String, h[:type])
      assert_kind_of(String, h[:url])
    end

    def test_name
      return unless @attachment

      assert_kind_of(String, @attachment.name)
      assert_predicate(@attachment, :present?)
    end

    def test_date
      return unless @attachment

      assert_kind_of([Time, NilClass], @attachment.date)
    end

    def test_size
      return unless @attachment

      assert_predicate(@attachment.size, :positive?)
    end

    def test_size_str
      return unless @attachment

      assert_kind_of(String, @attachment.size_str)
    end

    def test_width
      return unless @attachment

      assert_kind_of([Integer, NilClass], @attachment.width)
    end

    def test_height
      return unless @attachment

      assert_kind_of([Integer, NilClass], @attachment.height)
    end

    def test_description
      return unless @attachment

      assert_kind_of([String, NilClass], @attachment.description)
    end

    def test_meta
      return unless @attachment

      assert_kind_of(Hash, @attachment.meta)
    end

    def test_uri
      return unless @attachment

      assert_kind_of(Ginseng::URI, @attachment.uri)
      assert_predicate(@attachment.uri, :absolute?)
    end

    def test_thumbnail_uri
      return unless @attachment

      assert_kind_of(Ginseng::URI, @attachment.thumbnail_uri)
      assert_predicate(@attachment.thumbnail_uri, :absolute?)
    end

    def test_feed
      return unless @attachment

      assert_kind_of(Hash, attachment_class.feed.first)
    end

    def test_catalog
      return unless @attachment

      assert_kind_of(Hash, attachment_class.catalog.first)
      assert_kind_of(Hash, attachment_class.catalog(only_person: 1).first)
    end
  end
end
