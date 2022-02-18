module Mulukhiya
  class CustomAPITest < TestCase
    def test_all
      CustomAPI.all do |api|
        assert_kind_of(CustomAPI, api)
      end
    end

    def test_id
      CustomAPI.all do |api|
        assert_kind_of(String, api.id)
      end
    end

    def test_uri
      CustomAPI.all.reject(&:args?).each do |api|
        assert_kind_of(Ginseng::URI, api.uri)
        assert_kind_of(HTTParty::Response, http.get(api.uri))
      end
    end

    def test_path
      CustomAPI.all do |api|
        assert_kind_of(String, api.path)
      end
    end

    def test_fullpath
      CustomAPI.all do |api|
        assert_kind_of(String, api.fullpath)
      end
    end

    def test_choices
      CustomAPI.all.select(&:args?).each do |api|
        api.args.each do |arg|
          assert_kind_of(Array, api.choices(arg))
        end
      end
    end

    def test_create_command
      CustomAPI.all do |api|
        command = api.create_command
        assert_kind_of(CommandLine, command)
        if api.args?
          command.args.pop
          command.args.push(api.choices(api.args.first).first)
        end
        command.exec
        assert_equal(command.status, 0)
      end
    end

    def test_create_renderer
      CustomAPI.all.reject(&:args?).each do |api|
        assert_kind_of(Ginseng::Web::RawRenderer, api.create_renderer)
      end
    end

    def test_args
      CustomAPI.all do |api|
        assert_kind_of(Array, api.args)
      end
    end

    def test_args?
      CustomAPI.all do |api|
        assert_boolean(api.args?)
      end
    end

    def test_description
      CustomAPI.all do |api|
        assert_kind_of(String, api.description)
      end
    end

    def test_present?
      assert_boolean(CustomAPI.present?)
    end

    def test_to_json
      assert_kind_of(String, CustomAPI.to_json)
    end

    def test_count
      assert_kind_of(Integer, CustomAPI.count)
    end
  end
end
