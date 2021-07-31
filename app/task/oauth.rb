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

      # deprecated
      task show: ['default:show']

      # deprecated
      task clean: ['default:clean']

      # deprecated
      task clear: ['default:clean']

      # deprecated
      task show_infobot: ['infobot:show']

      # deprecated
      task clean_infobot: ['infobot:clean']

      # deprecated
      task clear_infobot: ['infobot:clean']
    end
  end
end
