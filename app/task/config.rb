namespace :config do
  desc 'lint local config'
  task :lint do
    puts "controller: #{Mulukhiya::Environment.controller_name}"
    puts "environment: #{Mulukhiya::Environment.type}"
    if Mulukhiya::Config.instance.errors.present?
      puts 'config:lint'
      puts Mulukhiya::Config.instance.errors.to_yaml
      exit 1
    else
      puts 'config:lint OK'
    end
  end
end
