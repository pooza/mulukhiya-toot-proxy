namespace :config do
  desc 'lint local config'
  task :lint do
    puts "controller: #{Mulukhiya::Environment.controller_name}"
    puts "environment: #{Mulukhiya::Environment.type}"
    puts 'schema:'
    puts Mulukhiya::Config.instance.schema.to_yaml
    if Mulukhiya::Config.instance.errors.present?
      puts 'result:'
      puts Mulukhiya::Config.instance.errors.to_yaml
      exit 1
    else
      puts 'result: OK'
    end
  end
end
