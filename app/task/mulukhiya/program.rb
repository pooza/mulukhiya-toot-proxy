module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :program do
      desc 'update programs'
      task :update do
        if Environment.production?
          ProgramUpdateWorker.perform_async
        else
          ProgramUpdateWorker.new.perform
        end
      end

      desc 'show programs'
      task :show do
        puts Program.instance.to_yaml
      end
    end
  end
end
