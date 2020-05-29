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
  end
end
