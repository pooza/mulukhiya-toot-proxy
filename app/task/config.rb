module Mulukhiya
  extend Rake::DSL

  namespace :config do
    desc 'lint local config'
    task :lint do
      puts "controller: #{Environment.controller_name}"
      puts "environment: #{Environment.type}"
      if Config.instance.errors.present?
        puts 'config:'
        puts Config.instance.errors.to_yaml
        exit 1
      else
        puts 'config: OK'
      end
    end
  end
end
