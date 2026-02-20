module Mulukhiya
  class TemplateTest < TestCase
    def disable?
      return true unless Environment.dbms_class&.config?
      return super
    rescue
      return true
    end

    def setup
      return if disable?
      @template = Template.new('mention/welcome')
    end

    def test_to_s
      assert(@template.to_s.chomp.end_with?('へようこそ。'))
    end
  end
end
