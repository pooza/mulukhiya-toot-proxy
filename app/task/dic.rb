namespace :mulukhiya do
  namespace :tagging do
    namespace :dic do
      desc 'update tagging dictionary'
      task :update do
        Mulukhiya::TaggingDictionaryUpdateWorker.new.perform
      end
    end
  end
end
