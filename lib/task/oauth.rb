namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      desc 'clean OAuth client ID'
      task :clean do
        mastodon = MulukhiyaTootProxy::Mastodon.new
        path = mastodon.oauth_client_path
        File.unlink(path) if File.exist?(path)
      end
    end
  end
end
