require 'json-schema'

namespace :config do
  desc 'lint local config'
  task :lint do
    puts "controller: #{controller}"
    errors = JSON::Validator.fully_validate(schema, config)
    if errors.present?
      puts YAML.dump(errors)
    else
      puts 'OK'
    end
  end

  def config
    return Mulukhiya::Config.instance.raw['local']
  end

  def schema
    return Mulukhiya::Config.instance.raw["schema.#{controller}"]
  end

  def controller
    return Mulukhiya::Environment.controller_name
  end
end
