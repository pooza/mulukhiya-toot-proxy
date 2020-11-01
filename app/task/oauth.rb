namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      desc 'clean OAuth client'
      task :clean do
        Mulukhiya::Environment.sns_class.new.clear_oauth_client
      end

      task clear: [:clean]

      desc 'show OAuth client'
      task :show do
        puts Mulukhiya::Environment.sns_class.new.oauth_client.to_yaml
      end
    end
  end
end
