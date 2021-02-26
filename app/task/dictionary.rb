namespace :mulukhiya do
  namespace :tagging do
    namespace :dic do
      desc 'update tagging dictionary'
      task :update do
        dic = Mulukhiya::TaggingDictionary.new
        dic.delete if dic.exist?
        dic.create
        puts "path: #{dic.path}"
        puts "#{dic.remote_dics.count} remote dics"
        puts "#{dic.count} tags"
      end
    end

    namespace :dictionary do
      task update: ['mulukhiya:tagging:dic:update']
    end
  end
end
