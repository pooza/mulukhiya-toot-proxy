module MulukhiyaTootProxy
  class TemplateTest < Test::Unit::TestCase
    def setup
      @template = Template.new('toot_notification')
      @template[:account] = {username: 'pooza'}
      @template[:status] = 'hoge'
    end

    def test_to_s
      assert_equal(@template.to_s, "From: @pooza\nhoge\n")
    end
  end
end
