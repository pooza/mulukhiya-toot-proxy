module Mulukhiya
  extend Rake::DSL
  include Package

  namespace :config do
    desc 'lint local config'
    task :lint do
      puts "controller: #{Environment.controller_name}"
      puts "environment: #{Environment.type}"
      if config.errors.present?
        puts 'config:'
        puts config.errors.to_yaml
        exit 1
      else
        puts 'config: OK'
      end
    end
  end
end
