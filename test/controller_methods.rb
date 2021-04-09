module Mulukhiya
  class ControllerMethodsTest < TestCase
    def test_name
      assert_kind_of(String, controller_class.name)
    end

    def test_display_name
      assert_kind_of(String, controller_class.display_name)
    end

    def test_webhook?
      assert_boolean(controller_class.webhook?)
    end

    def test_feed?
      assert_boolean(controller_class.feed?)
    end

    def test_announcement?
      assert_boolean(controller_class.announcement?)
    end

    def test_filter?
      assert_boolean(controller_class.filter?)
    end

    def test_streaming?
      assert_boolean(controller_class.streaming?)
    end

    def test_futured_tag?
      assert_boolean(controller_class.futured_tag?)
    end

    def test_favorite_tags?
      assert_boolean(controller_class.favorite_tags?)
    end

    def test_annict?
      assert_boolean(controller_class.annict?)
    end

    def test_livecure?
      assert_boolean(controller_class.livecure?)
    end

    def test_parser_name
      assert_kind_of(String, controller_class.parser_name)
    end

    def test_dbms_name
      assert_kind_of(String, controller_class.dbms_name)
    end

    def test_parser_class
      assert_kind_of(Class, controller_class.parser_class)
    end

    def test_dbms_class
      assert_kind_of(Class, controller_class.dbms_class)
    end

    def test_oauth_scopes
      assert_kind_of(Array, controller_class.oauth_scopes)
      assert(controller_class.oauth_scopes.present?)
      controller_class.oauth_scopes.each do |scope|
        assert_kind_of(String, scope)
      end
    end

    def test_status_field
      assert_kind_of(String, controller_class.status_field)
    end

    def test_poll_option_field
      assert_kind_of(String, controller_class.poll_options_field)
    end

    def test_spoiler_field
      assert_kind_of(String, controller_class.spoiler_field)
    end

    def test_attachment_field
      assert_kind_of(String, controller_class.attachment_field)
    end

    def test_status_key
      assert_kind_of(String, controller_class.status_key)
    end

    def test_status_label
      assert_kind_of(String, controller_class.status_label)
    end
  end
end
