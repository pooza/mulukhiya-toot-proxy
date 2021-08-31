module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :tagging do
      namespace :dic do
        desc 'update tagging dictionary'
        task :update do
          TaggingDictionaryUpdateWorker.perform_async
        end
      end
    end
  end
end
