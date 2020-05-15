namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      desc 'clean OAuth client ID'
      task :clean do
        Mulukhiya::Environment.sns_class.new.clear_oauth_client
      end
    end
  end
end
