module Mulukhiya
  extend Rake::DSL

  desc 'lint all'
  task lint: ['config:lint', 'erb:lint', 'slim:lint', 'rubocop:lint']
end
