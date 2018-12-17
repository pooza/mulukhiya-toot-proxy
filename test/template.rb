module MulukhiyaTootProxy
  class TemplateTest < Test::Unit::TestCase
    def setup
      @template = Template.new('test')
      @template[:body1] = 'body1'
      @template[:body2] = 'body2'
    end

    def test_to_s
      @template[:output] = 1
      assert_equal(@template.to_s, "body1\n")
      @template[:output] = 2
      assert_equal(@template.to_s, "body2\n")
    end
  end
end
