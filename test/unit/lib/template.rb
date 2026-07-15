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
      # welcome.erb は「<node_name>へようこそ。」の挨拶行に続けて案内行を持つ複数行
      # テンプレなので、末尾でなく挨拶行（1行目）が正しくレンダーされることを検証する。
      assert(@template.to_s.lines.first.chomp.end_with?('へようこそ。'))
    end
  end
end
