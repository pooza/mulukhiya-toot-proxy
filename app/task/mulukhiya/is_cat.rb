module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :is_cat do
      desc 'clear all is_cat cache entries'
      task :clear do
        storage = IsCatStorage.new
        keys = storage.all_keys
        storage.clear
        puts "cleared #{keys.size} key(s)"
      end

      desc 'show is_cat cache keys and TTL'
      task :status do
        storage = IsCatStorage.new
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
