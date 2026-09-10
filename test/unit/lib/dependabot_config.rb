module Mulukhiya
  # `.github/dependabot.yml` の `ignore` が `Gemfile` の上限と対になっていること (#4702)。
  #
  # ⚠⚠ **`versioning-strategy: increase-if-necessary` は、上限の外の版で manifest を動かす。**
  # `lockfile-only` のままでは ginseng の `tag:` が上がらない（PR #4716 の Codex P1）ので
  # 切り替えたが、そのままでは **json 3.0 / rack 3.3 / sinatra 4.3 のような、意図して
  # 据え置いている gem まで制約を広げる PR が出る**。`ignore` で止めている。
  #
  # 🔴 **`Gemfile` に上限を足したのに `ignore` を足し忘れると、据え置きの判断が黙って
  # 崩れる。**逆に上限を外したのに `ignore` が残ると、版上げが黙って止まる。
  # どちらも CI では気付けないので、ここで対を固定する。
  class DependabotConfigTest < TestCase
    MAJOR = 'version-update:semver-major'.freeze
    MINOR = 'version-update:semver-minor'.freeze

    def setup
      @config = YAML.load_file(File.join(Environment.dir, '.github/dependabot.yml'))
      @develop = @config['updates'].find {|u| u['target-branch'] == 'develop'}
      @ignores = Array(@develop['ignore']).to_h {|v| [v['dependency-name'], v['update-types']]}
    end

    # 🔴 **本体。**`~>` で上限を置いた gem には、上限の外へ出る版上げを止める `ignore` がある。
    #   `~> X.Y`   → 上限の外は major       → major を止める
    #   `~> X.Y.Z` → 上限の外は minor 以上  → minor と major を止める
    def test_every_capped_gem_is_ignored_beyond_its_cap
      capped_gems.each do |name, segments|
        types = @ignores[name]

        assert(types, "#{name} に上限があるのに ignore が無い（据え置きが崩れる）")
        assert_includes(types, MAJOR, "#{name} の major を止めていない")
        assert_includes(types, MINOR, "#{name} は ~> X.Y.Z なので minor も止める必要がある") if segments == 3
      end
    end

    # ⚠ 逆向き。上限を外したのに `ignore` が残っていると、版上げが黙って止まる。
    def test_no_stale_ignores
      stale = @ignores.keys - capped_gems.keys

      assert_empty(stale, "Gemfile に上限が無いのに ignore が残っている: #{stale.join(', ')}")
    end

    # ⚠⚠ **ginseng の `tag:` が上がる設定であること。**`lockfile-only` に戻ると、
    # ginseng グループから PR が 1 本も出なくなる（PR #4716 の Codex P1）。
    def test_strategy_permits_manifest_updates
      assert_not_equal('lockfile-only', @develop['versioning-strategy'])
    end

    # ⚠ ginseng を止めていないこと（ここを止めると #4701 の固定が凍結に変わる）。
    def test_ginseng_is_not_ignored
      assert(@ignores.keys.none? {|name| name.start_with?('ginseng')}, 'ginseng を ignore している')
    end

    private

    # `Gemfile` の `gem 'name', '~> X.Y[.Z]'` を拾う。ginseng（`tag:`）は対象外。
    def capped_gems
      path = File.join(Environment.dir, 'Gemfile')
      return File.readlines(path).filter_map do |line|
        next unless matches = line.match(/^\s*gem '([^']+)', *'~> *([0-9.]+)'/)
        [matches[1], matches[2].split('.').size]
      end.to_h
    end
  end
end
