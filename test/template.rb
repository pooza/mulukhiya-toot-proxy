module Mulukhiya
  class TemplateTest < TestCase
    def setup
      @template = Template.new('welcome')
    end

    def test_to_s
      assert(@template.to_s.chomp.end_with?('へようこそ。'))
    end
  end
end
