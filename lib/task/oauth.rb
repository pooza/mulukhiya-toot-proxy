namespace :mulukhiya do
  namespace :oauth do
    namespace :client do
      desc 'clean OAuth client ID'
      task :clean do
        config = MulukhiyaTootProxy::Config.instance
        mastodon = MulukhiyaTootProxy::Mastodon.new(config['/instance_url'])
        path = mastodon.oauth_client_path
        File.unlink(path) if File.exist?(path)
      end
    end
  end
end
