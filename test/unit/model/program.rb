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

    def test_data_normalizes_extra_tags_to_array
      key_missing = "test_extra_missing_#{Time.now.to_i}"
      key_present = "test_extra_present_#{Time.now.to_i}"
      original = @program.data
      @program.save(
        key_missing => {'series' => 'A'},
        key_present => {'series' => 'B', 'extra_tags' => ['tag1', 'tag2']},
      )
      data = @program.data

      assert_equal([], data[key_missing]['extra_tags'])
      assert_equal(['tag1', 'tag2'], data[key_present]['extra_tags'])
    ensure
      @program.save(original) if original
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

    def test_cache_failure_context
      ctx = @program.send(:cache_failure_context, {'k1' => {}, 'k2' => {}})

      assert_equal(2, ctx[:programs_size])
      assert_kind_of(Integer, ctx[:json_bytes])
      assert_operator(ctx[:json_bytes], :>, 0)
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

      error = assert_raise(Ginseng::ConflictError) do
        @program.add_entry(key, 'series' => 'B')
      end
      assert_equal(409, error.status)
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

    def test_update_entry_clears_key_when_value_is_nil
      key = "test_clear_#{Time.now.to_i}"
      original = @program.data
      @program.save(key => {'series' => 'A', 'subtitle' => 'old', 'episode' => 3})
      entry = @program.update_entry(key, 'subtitle' => nil)

      assert_not_includes(entry.keys, 'subtitle')
      assert_equal('A', entry['series'])
      assert_equal(3, entry['episode'])
    ensure
      @program.save(original) if original
    end

    def test_add_entry_drops_nil_attributes
      key = "test_addnil_#{Time.now.to_i}"
      original = @program.data
      @program.save({})
      entry = @program.add_entry(key, 'series' => 'A', 'subtitle' => nil, 'episode' => 1)

      assert_equal('A', entry['series'])
      assert_equal(1, entry['episode'])
      assert_not_includes(entry.keys, 'subtitle')
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

    def test_auto_update_default_true
      assert_true(@program.auto_update?)
    end

    def test_fetch_remote_merges_valid_payload
      return if disable?
      url = 'http://example.com/programs.json'
      payload = {'remote_a' => {'series' => 'Remote A'}}
      stub_remote_program(url, payload.to_json)
      with_program_urls([url]) do
        result = @program.send(:fetch_remote)

        assert_equal(payload, result)
      end
    end

    def test_fetch_remote_skips_oversize_body
      return if disable?
      url = 'http://example.com/oversize.json'
      stub_remote_program(url, 'x' * (Program::DEFAULT_FETCH_MAX_BYTES + 1))
      with_program_urls([url]) do
        result = @program.send(:fetch_remote)

        assert_nil(result)
      end
    end

    def test_fetch_remote_skips_non_hash_payload
      return if disable?
      url = 'http://example.com/array.json'
      stub_remote_program(url, [{'series' => 'A'}].to_json)
      with_program_urls([url]) do
        result = @program.send(:fetch_remote)

        assert_nil(result)
      end
    end

    def test_fetch_remote_skips_hash_with_non_hash_values
      return if disable?
      url = 'http://example.com/scalar_values.json'
      stub_remote_program(url, {'key' => 'not_a_hash'}.to_json)
      with_program_urls([url]) do
        result = @program.send(:fetch_remote)

        assert_nil(result)
      end
    end

    def test_fetch_remote_honors_configured_max_bytes
      original_max = config['/program/fetch/max_bytes']
      return if disable?
      url = 'http://example.com/configured.json'
      payload = {'remote_b' => {'series' => 'Remote B'}}
      body = payload.to_json
      stub_remote_program(url, body)
      config['/program/fetch/max_bytes'] = body.bytesize - 1
      with_program_urls([url]) do
        result = @program.send(:fetch_remote)

        assert_nil(result)
      end
    ensure
      config['/program/fetch/max_bytes'] = original_max if defined?(original_max)
    end

    def test_fetch_remote_returns_nil_when_all_urls_fail
      return if disable?
      url = 'http://example.com/fail.json'
      stub_request(:get, url).to_raise(StandardError.new('upstream down'))
      with_program_urls([url]) do
        result = @program.send(:fetch_remote)

        assert_nil(result)
      end
    end

    def test_update_preserves_existing_data_when_all_urls_fail
      return if disable?
      original = @program.data
      sentinel_key = "test_sentinel_#{Time.now.to_i}"
      @program.save(sentinel_key => {'series' => 'Sentinel', 'enable' => true})
      url = 'http://example.com/fail.json'
      stub_request(:get, url).to_raise(StandardError.new('upstream down'))
      with_program_urls([url]) do
        @program.update

        assert_includes(@program.data.keys, sentinel_key)
      end
    ensure
      @program.save(original) if original
    end

    def test_update_cache_invalidates_on_redis_write_failure
      original = @program.data
      @program.save({'sentinel' => {'series' => 'sentinel'}})

      failing_redis = Object.new
      unlinks = []
      failing_redis.define_singleton_method(:[]=) {|_k, _v| raise 'simulated redis failure'}
      failing_redis.define_singleton_method(:unlink) do |k|
        unlinks << k
        1
      end
      original_redis = @program.instance_variable_get(:@redis)
      @program.instance_variable_set(:@redis, failing_redis)

      result = @program.send(:update_cache, {'after' => {'series' => 'after'}})

      assert_nil(result)
      assert_equal([Program::REDIS_KEY], unlinks)
    ensure
      @program.instance_variable_set(:@redis, original_redis)
      @program.save(original) if original
    end

    private

    def stub_remote_program(url, body)
      stub_request(:get, url)
        .to_return(body:, headers: {'Content-Type' => 'application/json'})
    end

    def with_program_urls(urls)
      original = config['/program/urls']
      config['/program/urls'] = urls
      yield
    ensure
      config['/program/urls'] = original
    end
  end
end
