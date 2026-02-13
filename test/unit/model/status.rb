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
      h = @status.to_h

      assert_kind_of(Hash, h)
      assert_kind_of(String, h[:webui_url])
      assert_kind_of(String, h[:public_url])
      assert_kind_of(String, h[:created_at])
      assert_kind_of(String, h[:body])
      assert_kind_of(String, h[:footer])
      assert_kind_of(Array, h[:footer_tags])
      h[:footer_tags].each do |tag|
        assert_kind_of(Hash, tag)
      end
    end

    def test_date
      return unless @status

      assert_kind_of(Time, @status.date)
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
      return false unless @status

      assert_boolean(@status.local?)
    end

    def test_public?
      return false unless @status

      assert_boolean(@status.public?)
    end

    def test_nowplaying?
      return false unless @status

      assert_boolean(@status.nowplaying?)
    end

    def test_poipiku?
      return false unless @status

      assert_boolean(@status.poipiku?)
    end

    def test_taggable?
      return false unless @status

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
      assert_predicate(@status.uri, :absolute?)
    end

    def test_public_uri
      return unless @status

      assert_kind_of(Ginseng::URI, @status.public_uri)
    end

    def test_webui_uri
      return unless @status

      assert_kind_of(Ginseng::URI, @status.webui_uri)
    end

    def test_to_md
      return unless @status

      assert_kind_of(String, @status.to_md)
    end

    def test_default
      assert_kind_of(Hash, status_class.default)
      assert_kind_of([String, NilClass], status_class.default[:default_hashtag])
      assert_kind_of([String, NilClass], status_class.default[:spoiler_text])
    end

    def test_default_hashtag
      config['/handler/default_tag/tags'] = ['precure_fun']

      assert_equal('#precure_fun', status_class.default_hashtag)
      config['/handler/default_tag/tags'] = ['delmulin']

      assert_equal('#delmulin', status_class.default_hashtag)
      config['/handler/default_tag/tags'] = []

      assert_nil(status_class.default_hashtag)
      config['/handler/default_tag/tags'] = nil

      assert_nil(status_class.default_hashtag)
    end

    def test_spoiler_text
      config["/#{Environment.controller_name}/status/spoiler_text"] = ':netabare: '

      assert_equal(':netabare: ', status_class.spoiler_text)
      config["/#{Environment.controller_name}/status/spoiler_text"] = nil

      assert_nil(status_class.spoiler_text)
    end
  end
end
