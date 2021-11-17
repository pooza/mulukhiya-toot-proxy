module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :media do
      namespace :record do
        desc 'clean attachment records of test user'
        task :clean do
          Environment.account_class.test_account.clear_attachments
        end

        desc 'clean attachment records of test user (dryrun)'
        task :clean_dryrun do
          Environment.account_class.test_account.clear_attachments(dryrun: true)
        end

        task clear: [:clean]
      end

      namespace :file do
        desc 'clean media file cache'
        task :clean do
          MediaCleaningWorker.perform_async
        end

        task clear: [:clean]
      end

      namespace :meta do
        desc 'clean media metadata cache'
        task :clean do
          MediaMetadataStorage.new.clear
        end

        task clear: [:clean]
      end

      namespace :catalog do
        desc 'update media catalog'
        task :update do
          MediaCatalogUpdateWorker.perform_async
        end
      end
    end
  end
end
