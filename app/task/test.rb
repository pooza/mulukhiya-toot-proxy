desc 'test all'
task :test do
  ENV['TEST'] = MulukhiyaTootProxy::Package.name
  require 'test/unit'
  require 'sidekiq/testing'
  MulukhiyaTootProxy::Postgres.connect if MulukhiyaTootProxy::Postgres.config?
  Sidekiq::Testing.fake!
  Dir.glob(File.join(MulukhiyaTootProxy::Environment.dir, 'test/*.rb')).each do |t|
    require t
  end
end
