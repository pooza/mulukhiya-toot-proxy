namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      desc 'clean OAuth client'
      task :clean do
        Mulukhiya::Environment.sns_class.new.clear_oauth_client
      end

      desc 'show OAuth client'
      task :show do
        puts YAML.dump(Mulukhiya::Environment.sns_class.new.oauth_client)
      end
    end
  end
end
