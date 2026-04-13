module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :media_catalog do
      desc 'trigger media catalog cache update worker'
      task :update do
        MediaCatalogUpdateWorker.perform_async
      end

      desc 'clear all media catalog cache entries'
      task :clear do
        storage = MediaCatalogStorage.new
        keys = storage.all_keys
        storage.clear
        puts "cleared #{keys.size} key(s)"
      end

      desc 'show media catalog cache keys and TTL'
      task :status do
        storage = MediaCatalogStorage.new
        keys = storage.all_keys.sort
        if keys.empty?
          puts 'no cache entries'
          next
        end
        keys.each do |key|
          ttl = storage.redis.call('TTL', key)
          puts "#{key.ljust(48)}  ttl=#{ttl}"
        end
        puts "total: #{keys.size} key(s)"
      end
    end
  end
end
