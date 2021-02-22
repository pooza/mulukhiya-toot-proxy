namespace :mulukhiya do
  namespace :media do
    desc 'clean media file cache (deprecated)'
    task clean: 'file:clean'

    task clear: 'file:clean'

    namespace :record do
      desc 'clean attachment records of test user'
      task :clean do
        Mulukhiya::Environment.account_class.test_account.clear_attachments
      end

      desc 'clean attachment records of test user (dryrun)'
      task :clean_dryrun do
        Mulukhiya::Environment.account_class.test_account.clear_attachments(dryrun: true)
      end

      task clear: [:clean]
    end

    namespace :file do
      desc 'clean media file cache'
      task :clean do
        Mulukhiya::MediaFile.purge
      end

      task clear: [:clean]
    end

    namespace :meta do
      desc 'clean media metadata cache'
      task :clean do
        Mulukhiya::MediaMetadataStorage.new.clear
      end

      task clear: [:clean]
    end
  end
end
