namespace :mulukhiya do
  namespace :tagging do
    namespace :dictionary do
      desc 'update tagging dictionary'
      task :update do
        dic = MulukhiyaTootProxy::TaggingDictionary.new
        dic.delete unless dic.exist?
        dic.create
        puts "path: #{MulukhiyaTootProxy::TaggingDictionary.path}"
        puts "#{dic.resources.count} resources"
        puts "#{dic.count} tags"
      end
    end
  end
end
