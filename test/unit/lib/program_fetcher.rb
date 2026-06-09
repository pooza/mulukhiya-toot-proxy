module Mulukhiya
  class ProgramFetcherTest < TestCase
    def disable?
      return true unless controller_class.livecure?
      return super
    end

    def setup
      return if disable?
      @fetcher = ProgramFetcher.new
    end

    def test_uris
      assert_kind_of(Set, @fetcher.uris)
      @fetcher.uris.each do |uri|
        assert_kind_of(Addressable::URI, uri)
        assert_predicate(uri, :absolute?)
      end
    end

    def test_fetch_merges_valid_payload
      return if disable?
      url = 'http://example.com/programs.json'
      payload = {'remote_a' => {'series' => 'Remote A'}}
      stub_remote_program(url, payload.to_json)
      with_program_urls([url]) do
        result = @fetcher.fetch

        assert_equal(payload, result)
      end
    end

    def test_fetch_returns_nil_without_urls
      return if disable?
      result = with_program_urls([]) {@fetcher.fetch}

      assert_nil(result)
    end

    def test_fetch_skips_oversize_body
      return if disable?
      url = 'http://example.com/oversize.json'
      stub_remote_program(url, 'x' * (ProgramFetcher::DEFAULT_FETCH_MAX_BYTES + 1))
      with_program_urls([url]) do
        result = @fetcher.fetch

        assert_nil(result)
      end
    end

    def test_fetch_skips_non_hash_payload
      return if disable?
      url = 'http://example.com/array.json'
      stub_remote_program(url, [{'series' => 'A'}].to_json)
      with_program_urls([url]) do
        result = @fetcher.fetch

        assert_nil(result)
      end
    end

    def test_fetch_skips_hash_with_non_hash_values
      return if disable?
      url = 'http://example.com/scalar_values.json'
      stub_remote_program(url, {'key' => 'not_a_hash'}.to_json)
      with_program_urls([url]) do
        result = @fetcher.fetch

        assert_nil(result)
      end
    end

    def test_fetch_honors_configured_max_bytes
      original_max = config['/program/fetch/max_bytes']
      return if disable?
      url = 'http://example.com/configured.json'
      payload = {'remote_b' => {'series' => 'Remote B'}}
      body = payload.to_json
      stub_remote_program(url, body)
      config['/program/fetch/max_bytes'] = body.bytesize - 1
      with_program_urls([url]) do
        result = @fetcher.fetch

        assert_nil(result)
      end
    ensure
      config['/program/fetch/max_bytes'] = original_max if defined?(original_max)
    end

    def test_fetch_skips_before_get_when_content_length_exceeds_max
      return if disable?
      url = 'http://example.com/huge.json'
      payload = {'remote_c' => {'series' => 'Remote C'}}
      stub_remote_program(
        url, payload.to_json, content_length: ProgramFetcher::DEFAULT_FETCH_MAX_BYTES + 1
      )
      with_program_urls([url]) do
        result = @fetcher.fetch

        assert_nil(result)
        assert_not_requested(:get, url)
      end
    end

    def test_fetch_proceeds_when_head_unsupported
      return if disable?
      url = 'http://example.com/no_head.json'
      payload = {'remote_d' => {'series' => 'Remote D'}}
      stub_request(:head, url).to_return(status: 405)
      stub_request(:get, url)
        .to_return(body: payload.to_json, headers: {'Content-Type' => 'application/json'})
      with_program_urls([url]) do
        result = @fetcher.fetch

        assert_equal(payload, result)
      end
    end

    def test_fetch_returns_nil_when_all_urls_fail
      return if disable?
      url = 'http://example.com/fail.json'
      stub_request(:head, url).to_raise(StandardError.new('upstream down'))
      stub_request(:get, url).to_raise(StandardError.new('upstream down'))
      with_program_urls([url]) do
        result = @fetcher.fetch

        assert_nil(result)
      end
    end

    def test_fetch_timeout_returns_configured_value
      assert_kind_of(Integer, @fetcher.send(:fetch_timeout))
      assert_equal(config['/program/fetch/timeout'], @fetcher.send(:fetch_timeout))
    end

    def test_fetch_timeout_honors_config
      original = config['/program/fetch/timeout']
      config['/program/fetch/timeout'] = 7

      assert_equal(7, @fetcher.send(:fetch_timeout))
    ensure
      config['/program/fetch/timeout'] = original
    end

    def test_save_writes_yaml
      original = @fetcher.load
      data = {'test_program' => {'series' => 'TestSeries', 'enable' => true}}
      @fetcher.save(data)

      assert_predicate(@fetcher, :yaml_exist?)
      loaded = YAML.safe_load_file(ProgramFetcher::YAML_PATH, permitted_classes: [Symbol])

      assert_equal('TestSeries', loaded['test_program']['series'])
    ensure
      @fetcher.save(original) if defined?(original) && original
    end

    def test_invalidate_cache
      @fetcher.invalidate_cache

      assert_kind_of(Hash, @fetcher.load)
    end

    def test_cache_failure_context
      ctx = @fetcher.send(:cache_failure_context, {'k1' => {}, 'k2' => {}})

      assert_equal(2, ctx[:programs_size])
      assert_kind_of(Integer, ctx[:json_bytes])
      assert_operator(ctx[:json_bytes], :>, 0)
    end

    def test_update_cache_invalidates_on_redis_write_failure
      original = @fetcher.load
      @fetcher.save({'sentinel' => {'series' => 'sentinel'}})

      failing_redis = Object.new
      unlinks = []
      failing_redis.define_singleton_method(:[]=) {|_k, _v| raise 'simulated redis failure'}
      failing_redis.define_singleton_method(:unlink) do |k|
        unlinks << k
        1
      end
      original_redis = @fetcher.instance_variable_get(:@redis)
      @fetcher.instance_variable_set(:@redis, failing_redis)

      result = @fetcher.send(:update_cache, {'after' => {'series' => 'after'}})

      assert_nil(result)
      assert_equal([ProgramFetcher::REDIS_KEY], unlinks)
    ensure
      @fetcher.instance_variable_set(:@redis, original_redis)
      @fetcher.save(original) if defined?(original) && original
    end

    private

    def stub_remote_program(url, body, content_length: body.bytesize)
      stub_request(:head, url)
        .to_return(headers: {'Content-Length' => content_length.to_s})
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
