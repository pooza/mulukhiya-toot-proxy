module Mulukhiya
  class AttachmentTest < TestCase
    def setup
      @attachment = attachment_class[attachment_class.catalog.first[:id]]
    end

    test 'テスト用メディアファイルの有無' do
      assert(@attachment)
    end

    def test_to_h
      return unless @attachment
      assert_kind_of(Hash, @attachment.to_h)
    end

    def test_name
      return unless @attachment
      assert_kind_of(String, @attachment.name)
      assert(@attachment.present?)
    end

    def test_date
      return unless @attachment
      assert_kind_of([Time, NilClass], @attachment.date)
    end

    def test_size
      return unless @attachment
      assert_kind_of(Integer, @attachment.size)
    end

    def test_size_str
      return unless @attachment
      assert_kind_of(String, @attachment.size_str)
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
    end

    def test_feed
      return unless @attachment
      assert_kind_of(Hash, attachment_class.feed.first)
    end

    def test_catalog
      return unless @attachment
      assert_kind_of(Hash, attachment_class.catalog.first)
    end
  end
end
