module Mulukhiya
  class AttachmentTest < TestCase
    def setup
      @attachment = attachment_class[attachment_class.catalog.first[:_id]]
    end

    def test_to_h
      assert_kind_of(Hash, @attachment.to_h)
    end

    def test_name
      assert_kind_of(String, @attachment.name)
      assert(@attachment.present?)
    end

    def test_date
      assert_kind_of([Time, NilClass], @attachment.date)
    end

    def test_size
      assert_kind_of(Integer, @attachment.size)
    end

    def test_size_str
      assert_kind_of(String, @attachment.size_str)
    end

    def test_meta
      assert_kind_of(Hash, @attachment.meta)
    end

    def test_uri
      assert_kind_of(Ginseng::URI, @attachment.uri)
    end

    def test_feed
      assert_kind_of(Hash, attachment_class.feed.first)
    end

    def test_catalog
      assert_kind_of(Hash, attachment_class.catalog.first)
    end
  end
end
