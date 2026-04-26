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

    def test_add_entry_creates_new_entry
      key = "test_add_#{Time.now.to_i}"
      original = @program.data
      @program.save({})
      entry = @program.add_entry(key, 'series' => 'TestSeries', 'episode' => 1)

      assert_equal('TestSeries', entry['series'])
      assert_equal(1, entry['episode'])
      assert_includes(@program.data.keys, key)
    ensure
      @program.save(original) if original
    end

    def test_add_entry_rejects_duplicate
      key = "test_dup_#{Time.now.to_i}"
      original = @program.data
      @program.save(key => {'series' => 'A'})

      assert_raise(Ginseng::ValidateError) do
        @program.add_entry(key, 'series' => 'B')
      end
    ensure
      @program.save(original) if original
    end

    def test_update_entry_merges_attributes
      key = "test_update_#{Time.now.to_i}"
      original = @program.data
      @program.save(key => {'series' => 'A', 'episode' => 1})
      entry = @program.update_entry(key, 'episode' => 5)

      assert_equal('A', entry['series'])
      assert_equal(5, entry['episode'])
    ensure
      @program.save(original) if original
    end

    def test_update_entry_raises_when_missing
      original = @program.data

      assert_raise(Ginseng::NotFoundError) do
        @program.update_entry('does_not_exist', 'series' => 'X')
      end
    ensure
      @program.save(original) if original
    end

    def test_delete_entry_removes_key
      key = "test_delete_#{Time.now.to_i}"
      original = @program.data
      @program.save(key => {'series' => 'A'})
      removed = @program.delete_entry(key)

      assert_equal('A', removed['series'])
      assert_not_includes(@program.data.keys, key)
    ensure
      @program.save(original) if original
    end

    def test_delete_entry_returns_nil_when_missing
      original = @program.data

      assert_nil(@program.delete_entry('does_not_exist'))
    ensure
      @program.save(original) if original
    end

    def test_increment_episode
      key = "test_inc_#{Time.now.to_i}"
      original = @program.data
      @program.save(key => {'series' => 'A', 'episode' => 3, 'annict_episode_id' => 100})
      entry = @program.increment_episode(key)

      assert_equal(4, entry['episode'])
      assert_nil(entry['annict_episode_id'])
    ensure
      @program.save(original) if original
    end

    def test_increment_episode_starts_from_zero
      key = "test_inc0_#{Time.now.to_i}"
      original = @program.data
      @program.save(key => {'series' => 'A'})
      entry = @program.increment_episode(key)

      assert_equal(1, entry['episode'])
    ensure
      @program.save(original) if original
    end

    def test_generate_key_returns_12_chars_hex
      key = @program.generate_key('series' => 'TestSeries')

      assert_match(/\A[0-9a-f]{12}\z/, key)
    end

    def test_generate_key_avoids_collision
      original = @program.data
      existing = @program.generate_key('series' => 'X')
      @program.save(existing => {'series' => 'X'})
      generated = @program.generate_key('series' => 'X')

      assert_not_equal(existing, generated)
    ensure
      @program.save(original) if original
    end
  end
end
