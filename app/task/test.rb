desc 'test all'
task :test do
  ENV['TEST'] = MulukhiyaTootProxy::Package.name
  require 'test/unit'
  require 'sidekiq/testing'
  MulukhiyaTootProxy::Postgres.connect if MulukhiyaTootProxy::Postgres.config?
  Sidekiq::Testing.fake!

  config = MulukhiyaTootProxy::Config.instance
  tests = Dir.glob(File.join(MulukhiyaTootProxy::Environment.dir, 'test/*.rb'))
  if MulukhiyaTootProxy::Environment.ci?
    tests.delete_if{|t| config['/test/excludes/ci'].member?(File.basename(t, '.rb'))}
  end
  unless MulukhiyaTootProxy::Postgres.config?
    tests.delete_if{|t| config['/test/excludes/no_db'].member?(File.basename(t, '.rb'))}
  end
  unless MulukhiyaTootProxy::AmazonService.config?
    tests.delete_if{|t| config['/test/excludes/no_amazon'].member?(File.basename(t, '.rb'))}
  end
  unless MulukhiyaTootProxy::SpotifyService.config?
    tests.delete_if{|t| config['/test/excludes/no_spotify'].member?(File.basename(t, '.rb'))}
  end
  if config['/controller'] == 'mastodon'
    tests.delete_if{|t| config['/test/excludes/mastodon'].member?(File.basename(t, '.rb'))}
  end
  if config['/controller'] == 'dolphin'
    tests.delete_if{|t| config['/test/excludes/dolphin'].member?(File.basename(t, '.rb'))}
  end
  tests.each{|t| require t}
end
