namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      desc 'clean OAuth client ID'
      task :clean do
        path = MulukhiyaTootProxy::Mastodon.new.oauth_client_path
        File.unlink(path) if File.exist?(path)
      end
    end
  end
end
