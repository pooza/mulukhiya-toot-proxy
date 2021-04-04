module Mulukhiya
  class ProgramTest < TestCase
    def setup
      @program = Program.instance
    end

    def test_data
      assert_kind_of(Hash, @program.data)
    end

    def test_count
      assert(@program.count.positive?)
    end

    def test_to_yaml
      assert_kind_of(Psych::Nodes::Document, YAML.parse(@program.to_yaml))
    end
  end
end
