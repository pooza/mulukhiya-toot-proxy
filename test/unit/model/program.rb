module Mulukhiya
  class ProgramTest < TestCase
    def disable?
      return true unless controller_class.livecure?
      return super
    end

    def setup
      return if disable?
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

      assert_predicate(@program, :yaml_exist?)
    end

    def test_save
      data = {'test_program' => {'series' => 'TestSeries', 'enable' => true}}
      @program.save(data)

      assert_predicate(@program, :yaml_exist?)
      loaded = YAML.safe_load_file(Program::YAML_PATH, permitted_classes: [Symbol])

      assert_equal('TestSeries', loaded['test_program']['series'])
    ensure
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

    def test_yaml_exist
      assert_boolean(@program.yaml_exist?)
    end

    def test_invalidate_cache
      @program.invalidate_cache

      assert_kind_of(Hash, @program.data)
    end
  end
end
