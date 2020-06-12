
namespace :config do
  desc 'lint local config'
  task :lint do
    puts "controller: #{Mulukhiya::Environment.controller_name}"
    puts "environment: #{Mulukhiya::Environment.type}"
    puts 'schema:'
    puts YAML.dump(Mulukhiya::Config.instance.schema)
    if Mulukhiya::Config.instance.errors.present?
      puts 'result:'
      puts YAML.dump(Mulukhiya::Config.instance.errors)
      exit 1
    else
      puts 'result: OK'
    end
  end
end
