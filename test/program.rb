module Mulukhiya
  class ProgramTest < TestCase
    def disable?
      return true unless controller_class.livecure?
      return super
    end

    def setup
      @program = Program.instance
    end

    def test_uris
      assert_kind_of(Set, @program.uris)
      @program.uris.each do |uri|
        assert_kind_of(Addressable::URI, uri)
        assert_predicate(uri, :absolute?)
      end
    end

    def test_update
      @program.update
    end

    def test_data
      assert_kind_of(Hash, @program.data)
    end

    def test_count
      assert_predicate(@program.count, :positive?)
    end

    def test_to_yaml
      assert_kind_of(Psych::Nodes::Document, YAML.parse(@program.to_yaml))
    end
  end
end
