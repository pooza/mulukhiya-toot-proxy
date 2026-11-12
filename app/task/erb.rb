module Mulukhiya
  extend Rake::DSL

  namespace :erb do
    desc 'lint all ERB templates'
    task :lint do
      # Ginseng::Template と同じ trim_mode でコンパイルし、Ruby の構文エラーだけを見る（実行はしない）。
      # erb_lint は HTML 向けで構文エラーを検出しないので使わない（#4229）。
      errors = Dir.glob(File.join(Environment.dir, 'views/**/*.erb')).filter_map do |path|
        RubyVM::InstructionSequence.compile(ERB.new(File.read(path), trim_mode: '-').src, path)
        nil
      rescue SyntaxError => e
        "#{path}: #{e.message}"
      end
      abort(errors.join("\n")) if errors.any?
      puts 'erb:lint: no errors'
    end
  end
end
