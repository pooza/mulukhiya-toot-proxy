module Mulukhiya
  class StatusTest < TestCase
    def setup
      @status = account.recent_status
    end

    test 'テスト用投稿の有無' do
      assert_not_nil(account.recent_status)
    end

    def test_service
      return unless @status
      assert_kind_of(Ginseng::Fediverse::Service, @status.service)
    end

    def test_parser
      return unless @status
      assert_kind_of(Ginseng::Fediverse::Parser, @status.parser)
    end

    def test_id
      return unless @status
      assert_predicate(@status.id, :present?)
    end

    def test_to_h
      return unless @status
      assert_kind_of(Hash, @status.to_h)
    end

    def test_account
      return unless @status
      assert_kind_of(account_class, @status.account)
    end

    def test_attachments
      return unless @status
      @status.attachments.each do |attachment|
        assert_kind_of([attachment_class, Hash], attachment)
      end
    end

    def test_local?
      return unless @status
      assert_boolean(@status.local?)
    end

    def test_public?
      return unless @status
      assert_boolean(@status.public?)
    end

    def test_taggable?
      return unless @status
      assert_boolean(@status.taggable?)
    end

    def test_body
      return unless @status
      assert_kind_of(String, @status.body)
    end

    def test_footer
      return unless @status
      assert_kind_of(String, @status.footer)
    end

    def test_footer_tags
      return unless @status
      assert_kind_of(Array, @status.footer_tags)
      @status.footer_tags.each do |tag|
        assert_kind_of(hash_tag_class, tag)
      end
    end

    def test_visibility_name
      return unless @status
      assert_kind_of(String, @status.visibility_name)
      assert(@status.parser.class.visibility_names.values.member?(@status.visibility_name))
    end

    def test_visibility_icon
      return unless @status
      assert_kind_of(String, @status.visibility_icon)
    end

    def test_text
      return unless @status
      assert_kind_of(String, @status.text)
    end

    def test_uri
      return unless @status
      assert_kind_of(Ginseng::URI, @status.uri)
    end

    def test_public_uri
      return unless @status
      assert_kind_of(Ginseng::URI, @status.public_uri)
    end

    def test_to_md
      return unless @status
      assert_kind_of(String, @status.to_md)
    end
  end
end
