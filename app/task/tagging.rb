namespace :mulukhiya do
  namespace :tagging do
    namespace :dictionary do
      desc 'update tagging dictionary'
      task :update do
        dic = Mulukhiya::TaggingDictionary.new
        dic.delete if dic.exist?
        dic.create
        puts "path: #{dic.path}"
        puts "#{dic.remote_dics.count} remote_dics"
        puts "#{dic.count} tags"
      end
    end

    namespace :feed do
      desc 'update feed'
      task :update do
        Mulukhiya::TagAtomFeedRenderer.cache_all
        Mulukhiya::TagAtomFeedRenderer.all do |renderer|
          puts "updated: ##{renderer.tag} #{renderer.path}"
        end
      end
    end
  end
end
