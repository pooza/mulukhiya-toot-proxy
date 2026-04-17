module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :program do
      desc 'update programs'
      task :update do
        ProgramUpdateWorker.perform_async
      end

      desc 'show programs'
      task :show do
        puts Program.instance.to_yaml
      end

      desc 'show program status'
      task :status do
        program = Program.instance
        puts "YAML path: #{Program::YAML_PATH}"
        puts "YAML exists: #{program.yaml_exist?}"
        puts "Program count: #{program.count}"
      end

      desc 'clear program cache'
      task :clear do
        Program.instance.invalidate_cache
        puts 'Program cache cleared.'
      end
    end
  end
end
