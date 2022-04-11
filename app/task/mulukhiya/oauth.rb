module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :oauth do
      namespace :client do
        [:default, :infobot].each do |client|
          namespace client do
            desc "show OAuth client (#{client})"
            task :show do
              puts Environment.sns_class.new.oauth_client(client).deep_stringify_keys.to_yaml
            end

            desc "clean OAuth client (#{client})"
            task :clean do
              Environment.sns_class.new.clear_oauth_client(client)
            end

            task clear: [:clean]
          end
        end
      end
    end
  end
end
