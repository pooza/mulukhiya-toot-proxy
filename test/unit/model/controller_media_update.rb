module Mulukhiya
  # ALT 編集の可否フラグ (#4636)。
  #
  # ⚠ **モロヘイヤの版番号では決まらない。**刺している ginseng-fediverse が
  # 1.8.30 未満だと、モロヘイヤ自身の上流 PUT が `X-Mulukhiya` を名乗らず
  # nginx の map に弾かれて 405 になる (#4621)。ゲートが**実際にブロックする**
  # ことを正面から確かめる。
  class ControllerMediaUpdateTest < TestCase
    def test_blocked_by_old_fediverse
      with_fediverse_version('1.8.29') do
        assert_false(MastodonController.media_update?)
      end
    end

    def test_enabled_by_fixed_fediverse
      with_fediverse_version('1.8.30') do
        assert_true(MastodonController.media_update?)
      end
    end

    def test_enabled_by_newer_fediverse
      with_fediverse_version('1.9.0') do
        assert_true(MastodonController.media_update?)
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
      with_fediverse_spec(nil) do
        assert_false(MastodonController.media_update?)
      end
    end

    private

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
