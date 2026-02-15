module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    namespace :oauth do
      namespace :client do
        desc 'show OAuth client'
        task :show do
          puts Environment.sns_class.new.oauth_client.to_yaml
        end

        desc 'clean OAuth client'
        task :clean do
          Environment.sns_class.new.clear_oauth_client
        end

        task clear: [:clean]
      end
    end
  end
end
