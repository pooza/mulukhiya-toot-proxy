module Mulukhiya
  # ALT 編集の可否フラグ (#4636)。
  #
  # 通るには 2 つの前提が要り、**どちらもモロヘイヤの版番号では判定できない**:
  # nginx の map が是正済みか (#4474・サーバーごとに乖離する) と、刺している
  # ginseng-fediverse が 1.8.30 以降か (#4621)。どちらのゲートも**実際に
  # ブロックする**ことを正面から確かめる。
  class ControllerMediaUpdateTest < TestCase
    CAPABILITY_PATH = '/mastodon/capabilities/media_update'.freeze

    def test_blocked_by_old_fediverse
      with_capability(true) do
        with_fediverse_version('1.8.29') do
          assert_false(MastodonController.media_update?)
        end
      end
    end

    # nginx の経路が未是正のサーバー (pooza/chubo2#188) は、gem が新しくても
    # 上流 PUT が 405 になる。opt-in が無ければ名乗らない。
    def test_blocked_without_capability
      with_capability(false) do
        with_fediverse_version('1.8.30') do
          assert_false(MastodonController.media_update?)
        end
      end
    end

    def test_enabled_by_capability_and_fixed_fediverse
      with_capability(true) do
        with_fediverse_version('1.8.30') do
          assert_true(MastodonController.media_update?)
        end
      end
    end

    def test_enabled_by_newer_fediverse
      with_capability(true) do
        with_fediverse_version('1.9.0') do
          assert_true(MastodonController.media_update?)
        end
      end
    end

    # ALT 編集の経路 (`PUT /api/:version/statuses/:id`) は MastodonController に
    # しか無く、capability も mastodon 側にしか置いていない。
    def test_misskey_is_always_false
      with_fediverse_version('1.9.0') do
        assert_false(MisskeyController.media_update?)
      end
    end

    # gem が読み込まれていない構成では「分からない」を false へ倒す。
    def test_false_without_fediverse_gem
      with_capability(true) do
        with_fediverse_spec(nil) do
          assert_false(MastodonController.media_update?)
        end
      end
    end

    # 既定は fail-closed。サーバーごとに local.yaml で opt-in する。
    def test_capability_defaults_to_false
      assert_false(config[CAPABILITY_PATH])
    end

    private

    def with_capability(value)
      original = config[CAPABILITY_PATH]
      config[CAPABILITY_PATH] = value
      yield
    ensure
      config[CAPABILITY_PATH] = original
    end

    def with_fediverse_version(version, &)
      with_fediverse_spec(Struct.new(:version).new(Gem::Version.new(version)), &)
    end

    def with_fediverse_spec(spec)
      original = Gem.loaded_specs['ginseng-fediverse']
      replace_fediverse_spec(spec)
      yield
    ensure
      replace_fediverse_spec(original)
    end

    def replace_fediverse_spec(spec)
      if spec.nil?
        Gem.loaded_specs.delete('ginseng-fediverse')
      else
        Gem.loaded_specs['ginseng-fediverse'] = spec
      end
    end
  end
end
