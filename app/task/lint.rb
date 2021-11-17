module Mulukhiya
  extend Rake::DSL

  desc 'lint all'
  task lint: ['erb:lint', 'slim:lint', 'rubocop:lint']
end
