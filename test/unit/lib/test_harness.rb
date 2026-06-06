require 'tmpdir'

module Mulukhiya
  class TestHarnessTest < TestCase
    ENV_KEYS = [
      'MASTODON_URL', 'MASTODON_ACCESS_TOKEN', 'MASTODON_INFO_ACCESS_TOKEN', 'MASTODON_DB_DSN',
      'MISSKEY_URL', 'MISSKEY_ACCESS_TOKEN', 'MISSKEY_INFO_ACCESS_TOKEN', 'MISSKEY_DB_DSN',
      'MULUKHIYA_HARNESS_DIR'
    ].freeze

    def setup
      @saved = ENV_KEYS.to_h {|key| [key, ENV.fetch(key, nil)]}
      ENV_KEYS.each {|key| ENV.delete(key)}
      # apply! は raw['local'] を恒久変更するため、退避して後続テストへの漏れを防ぐ。
      @saved_local = config.raw['local']&.dup
    end

    def teardown
      @saved.each {|key, value| value.nil? ? ENV.delete(key) : ENV[key] = value}
      config.raw['local'] = @saved_local
      super
    end

    def test_connections_from_env
      ENV['MASTODON_URL'] = 'http://localhost:3000'
      ENV['MASTODON_ACCESS_TOKEN'] = 'mastodon_token'
      info = TestHarness.new.connections

      assert_equal('http://localhost:3000', info['mastodon'][:url])
      assert_equal('mastodon_token', info['mastodon'][:token])
      assert_nil(info['misskey'])
    end

    def test_connections_ignores_partial_env
      ENV['MASTODON_URL'] = 'http://localhost:3000'
      info = TestHarness.new.connections

      assert_empty(info)
    end

    def test_connections_from_env_test_files
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'misskey')
        FileUtils.mkdir_p(path)
        File.write(File.join(path, '.env.test'), <<~ENV)
          # fedi-test-harness / Misskey
          MISSKEY_URL=http://localhost:3001
          MISSKEY_ACCESS_TOKEN=misskey_token
        ENV
        ENV['MULUKHIYA_HARNESS_DIR'] = dir
        info = TestHarness.new.connections

        assert_equal('http://localhost:3001', info['misskey'][:url])
        assert_equal('misskey_token', info['misskey'][:token])
      end
    end

    def test_env_takes_precedence_over_file
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'mastodon')
        FileUtils.mkdir_p(path)
        File.write(File.join(path, '.env.test'), <<~ENV)
          MASTODON_URL=http://from-file:3000
          MASTODON_ACCESS_TOKEN=file_token
        ENV
        ENV['MULUKHIYA_HARNESS_DIR'] = dir
        ENV['MASTODON_URL'] = 'http://from-env:3000'
        ENV['MASTODON_ACCESS_TOKEN'] = 'env_token'
        info = TestHarness.new.connections

        assert_equal('http://from-env:3000', info['mastodon'][:url])
        assert_equal('env_token', info['mastodon'][:token])
      end
    end

    def test_apply_injects_configured_controller
      config['/controller'] = 'mastodon'
      ENV['MASTODON_URL'] = 'http://localhost:3000'
      ENV['MASTODON_ACCESS_TOKEN'] = 'mastodon_token'
      conn = TestHarness.apply!

      assert_equal('mastodon_token', conn[:token])
      assert_equal('mastodon', config['/controller'])
      assert_equal('http://localhost:3000', config['/mastodon/url'])
      assert_equal('mastodon_token', config['/agent/test/token'])
    end

    def test_apply_selects_sole_available_controller
      config['/controller'] = 'mastodon'
      ENV['MISSKEY_URL'] = 'http://localhost:3001'
      ENV['MISSKEY_ACCESS_TOKEN'] = 'misskey_token'
      conn = TestHarness.apply!

      assert_equal('misskey_token', conn[:token])
      assert_equal('misskey', config['/controller'])
      assert_equal('http://localhost:3001', config['/misskey/url'])
    end

    def test_apply_is_noop_without_connection_info
      config['/controller'] = 'mastodon'

      assert_nil(TestHarness.apply!)
      assert_equal('mastodon', config['/controller'])
    end

    def test_connections_captures_info_token_and_db_dsn
      ENV['MASTODON_URL'] = 'http://localhost:3000'
      ENV['MASTODON_ACCESS_TOKEN'] = 'mastodon_token'
      ENV['MASTODON_INFO_ACCESS_TOKEN'] = 'info_token'
      ENV['MASTODON_DB_DSN'] = 'postgres://mastodon:mastodon@127.0.0.1:5433/mastodon_production'
      info = TestHarness.new.connections['mastodon']

      assert_equal('info_token', info[:info_token])
      assert_equal('postgres://mastodon:mastodon@127.0.0.1:5433/mastodon_production', info[:db_dsn])
    end

    def test_apply_wires_info_token_and_postgres_dsn
      config['/controller'] = 'mastodon'
      ENV['MASTODON_URL'] = 'http://localhost:3000'
      ENV['MASTODON_ACCESS_TOKEN'] = 'mastodon_token'
      ENV['MASTODON_INFO_ACCESS_TOKEN'] = 'info_token'
      ENV['MASTODON_DB_DSN'] = 'postgres://u:p@127.0.0.1:5433/db'
      TestHarness.apply!

      assert_equal('info_token', config['/agent/info/token'])
      assert_equal('postgres://u:p@127.0.0.1:5433/db', config['/postgres/dsn'])
    end

    def test_apply_omits_optional_fields_when_absent
      config['/controller'] = 'mastodon'
      ENV['MASTODON_URL'] = 'http://localhost:3000'
      ENV['MASTODON_ACCESS_TOKEN'] = 'mastodon_token'
      conn = TestHarness.apply!

      assert_nil(conn[:info_token])
      assert_nil(conn[:db_dsn])
    end
  end
end
