module Mulukhiya
  class TemplateTest < TestCase
    def disable?
      return true if Environment.ci?
      return super
    end

    def setup
      @template = Template.new('mention/welcome')
    end

    def test_to_s
      assert(@template.to_s.chomp.end_with?('へようこそ。'))
    end
  end
end
