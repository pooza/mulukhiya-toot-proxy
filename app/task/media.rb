namespace :mulukhiya do
  namespace :media do
    desc 'clean media file cache (deprecated)'
    task clean: 'file:clean'

    task clear: 'file:clean'

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
