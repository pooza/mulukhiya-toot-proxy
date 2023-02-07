module Mulukhiya
  extend Rake::DSL

  namespace :yaml do
    desc 'lint all YAML files'
    task :lint do
      sh %(find . -name '*.yaml' -not -name '._*' | xargs yamllint)
    end
  end
end
