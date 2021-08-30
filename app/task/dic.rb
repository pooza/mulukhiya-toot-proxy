namespace :mulukhiya do
  namespace :tagging do
    namespace :dic do
      desc 'update tagging dictionary'
      task :update do
        Mulukhiya::TaggingDictionaryUpdateWorker.perform_async
      end
    end
  end
end
