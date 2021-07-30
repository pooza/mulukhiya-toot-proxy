namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      [:default, :infobot].each do |client|
        namespace client do
          desc "show OAuth client (#{client})"
          task :show do
            puts Mulukhiya::Environment.sns_class.new.oauth_client(client).to_yaml
          end

          desc "clean OAuth client (#{client})"
          task :clean do
            Mulukhiya::Environment.sns_class.new.clear_oauth_client(client)
          end

          task clear: [:clean]
        end
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
