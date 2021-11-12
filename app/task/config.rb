module Mulukhiya
  extend Rake::DSL
  include Package

  namespace :config do
    desc 'lint local config'
    task :lint do
      result = {controller: Environment.controller_name, environment: Environment.type}
      if config.errors.present?
        result[:config] = config.errors
        puts result.deep_stringify_keys.to_yaml
        exit 1
      else
        result[:handlers] = Handler.names.to_a.sort
        result[:config] = 'OK'
        puts result.deep_stringify_keys.to_yaml
      end
    end

    desc 'show schema'
    task :schema do
      puts config.schema.to_yaml
    end
  end
end
