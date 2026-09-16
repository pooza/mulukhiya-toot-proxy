require 'slim_lint'

module Mulukhiya
  # ⚠⚠ **#4578: slim-lint が views/ 直下の 16 本を一度も検査していなかった。**
  # `rake slim:lint` が `views/**/*.slim` という**シェルの glob**を渡しており、
  # dash には globstar が無いので `views/*/*.slim` と等価になっていた。
  # ⚠ **それでも `rake lint` は緑で通っていた**（#4503 と同じ「守れているつもりの緑」）。
  #
  # 検査対象は「テンプレートを 1 本足したら自動で入る」性質のものなので、
  # 本数を固定するのではなく**実体との一致**を突き合わせる。
  class SlimLintCoverageTest < TestCase
    def test_views_has_top_level_templates
      # この前提が崩れると下の 2 本が「何も検査していないのに緑」になる。
      assert_not_empty(
        Dir.glob(File.join(views_dir, '*.slim')),
        'views/ 直下にテンプレートが 1 本も無い',
      )
    end

    def test_linter_covers_every_template
      assert_equal(
        Dir.glob(File.join(views_dir, '**', '*.slim')).map {|f| File.expand_path(f)}.sort,
        linter_targets,
        'slim-lint の検査対象が views/ 配下のテンプレート全体と一致しない',
      )
    end

    # ⚠ 上のテストは「ディレクトリを渡せば全部拾える」ことしか見ない。
    # タスク側がシェルの glob へ戻ると、**このテストは緑のまま lint だけが空振りする**。
    def test_task_does_not_rely_on_shell_glob
      assert_not_match(
        /\*\*/, task_source,
        'app/task/slim.rb がシェルの再帰 glob に頼っている (#4578)'
      )
    end

    private

    def views_dir
      return File.join(Environment.dir, 'views')
    end

    # ⚠ コメント行は落とす。**このタスクの罠そのものをコメントで説明している**ので、
    # 素のソースに当てると解説文で引っかかる。
    def task_source
      return File.read(File.join(Environment.dir, 'app/task/slim.rb'))
          .each_line.grep_v(/^\s*#/).join
    end

    def linter_targets
      config = SlimLint::ConfigurationLoader.load_applicable_config
      return SlimLint::FileFinder.new(config)
          .find([views_dir], [])
          .map {|f| File.expand_path(f)}
          .sort
    end
  end
end
