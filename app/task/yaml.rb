module Mulukhiya
  extend Rake::DSL

  namespace :yaml do
    desc 'lint all YAML files'
    task :lint do
      finder = Ginseng::FileFinder.new
      finder.dir = Environment.dir
      finder.patterns.push('*.yaml')
      finder.patterns.push('*.yml')
      finder.exec.each do |f|
        puts f
        sh "yamllint #{f}"
      end
    end
  end
end
