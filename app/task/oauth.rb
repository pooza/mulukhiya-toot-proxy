namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      desc 'clean OAuth client'
      task :clean do
        Mulukhiya::Environment.sns_class.new.clear_oauth_client
      end

      task clear: [:clean] # rubocop:disable Rake/Desc

      desc 'clean OAuth client (infobot)'
      task :clean_infobot do
        Mulukhiya::Environment.sns_class.new.clear_oauth_client(:infobot)
      end

      task clear_infobot: [:clean_infobot] # rubocop:disable Rake/Desc

      desc 'show OAuth client'
      task :show do
        puts Mulukhiya::Environment.sns_class.new.oauth_client.to_yaml
      end

      desc 'show OAuth client (infobot)'
      task :show_infobot do
        puts Mulukhiya::Environment.sns_class.new.oauth_client(:infobot).to_yaml
      end
    end
  end
end
