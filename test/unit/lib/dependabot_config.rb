module Mulukhiya
  # `.github/dependabot.yml` の `ignore` が `Gemfile` の上限と対になっていること (#4702)。
  #
  # ⚠⚠ **`versioning-strategy: increase-if-necessary` は、上限の外の版で manifest を動かす。**
  # そのままでは **json 3.0 / rack 3.3 / sinatra 4.3 のような、意図して
  # 据え置いている gem まで制約を広げる PR が出る**。`ignore` で止めている。
  #
  # 🔴 **`Gemfile` に上限を足したのに `ignore` を足し忘れると、据え置きの判断が黙って
  # 崩れる。**逆に上限を外したのに `ignore` が残ると、版上げが黙って止まる。
  # どちらも CI では気付けないので、ここで対を固定する。
  class DependabotConfigTest < TestCase
    MAJOR = 'version-update:semver-major'.freeze
    MINOR = 'version-update:semver-minor'.freeze
    GINSENG = 'ginseng-*'.freeze

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
      stale = @ignores.keys - capped_gems.keys - [GINSENG]

      assert_empty(stale, "Gemfile に上限が無いのに ignore が残っている: #{stale.join(', ')}")
    end

    # ⚠⚠ **ginseng-* は version update の対象外であること**（#4702）。版上げは同期手順
    # （docs/CLAUDE.md §6-1）で gem ごとに判断する。`update-types` を付けると一部の版上げが
    # 素通りするので、**全種別を止める（`update-types` 無し）**形であることまで見る。
    def test_ginseng_is_ignored_entirely
      assert(@ignores.key?(GINSENG), 'ginseng-* を ignore していない')
      assert_nil(@ignores[GINSENG], 'ginseng-* の ignore に update-types が付いている（一部が素通りする）')
    end

    # ⚠ 止め方は `ignore` であって `allow` ではないこと。`allow` は security update にも効くので、
    # 他の gem の脆弱性 PR まで止まる。
    def test_no_allow
      assert_nil(@develop['allow'])
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
