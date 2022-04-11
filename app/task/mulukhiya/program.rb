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
        puts Program.instance.deep_stringify_keys.to_yaml
      end
    end
  end
end
