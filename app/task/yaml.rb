module Mulukhiya
  extend Rake::DSL

  namespace :yaml do
    desc 'lint all YAML files'
    task :lint do
      finder = Ginseng::FileFinder.new
      finder.dir = Environment.dir
      finder.patterns.push('*.yaml')
      finder.patterns.push('*.yml')
      errors = []
      finder.exec.each do |f|
        YAML.safe_load_file(f, permitted_classes: [Symbol, Date, Time, Regexp])
      rescue Psych::SyntaxError => e
        errors.push("#{f}: #{e.message}")
      end
      if errors.empty?
        puts "#{finder.exec.count} YAML files checked, no errors."
      else
        errors.each {|e| warn e}
        abort "#{errors.count} YAML error(s) found."
      end
    end
  end
end
