module Mulukhiya
  extend Rake::DSL

  namespace :slim do
    desc 'lint all Slim templates'
    task :lint do
      # ⚠ シェルの glob に頼らない。`views/**/*.slim` は dash に globstar が無いので
      # `views/*/*.slim` と等価になり、views/ 直下の 16 本が一度も検査されなかった (#4578)。
      # slim_lint はディレクトリを再帰するので、ディレクトリだけ渡す。
      # ⚠ 引数を分けて渡す＝シェルを経由しない。`sh 'bundle exec slim-lint', path` と
      # 1 つ目にまとめると、その全体が 1 つのプログラム名として exec され status 127 になる。
      sh 'bundle', 'exec', 'slim-lint', File.join(Environment.dir, 'views')
    end
  end
end
