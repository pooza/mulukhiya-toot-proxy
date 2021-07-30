namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      namespace :default do
        desc 'show OAuth client (default)'
        task :show do
          puts Mulukhiya::Environment.sns_class.new.oauth_client.to_yaml
        end

        desc 'clean OAuth client (default)'
        task :clean do
          Mulukhiya::Environment.sns_class.new.clear_oauth_client
        end

        task clear: [:clean]
      end

      namespace :infobot do
        desc 'show OAuth client (infobot)'
        task :show do
          puts Mulukhiya::Environment.sns_class.new.oauth_client(:infobot).to_yaml
        end

        desc 'clean OAuth client (infobot)'
        task :clean do
          Mulukhiya::Environment.sns_class.new.clear_oauth_client(:infobot)
        end

        task clear: [:clean]
      end

      task show: ['default:show']

      task clean: ['default:clean']

      task clear: ['default:clean']

      task show_infobot: ['infobot:show']

      task clean_infobot: ['infobot:clean']

      task clear_infobot: ['infobot:clean']
    end
  end
end
