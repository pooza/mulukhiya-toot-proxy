module MulukhiyaTootProxy
  class SlackTest < Test::Unit::TestCase
    def test_all
      Slack.all do |slack|
        assert(slack.is_a?(Slack))
      end
    end

    def test_say
      Slack.all do |slack|
        assert(slack.say({text: Package.full_name}).response.is_a?(Net::HTTPOK))
      end
    end
  end
end
