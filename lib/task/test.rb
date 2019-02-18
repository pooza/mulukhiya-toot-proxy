namespace :mulukhiya do
  desc 'test mulukhiya'
  task :test do
    ENV['TEST'] = MulukhiyaTootProxy::Package.name
    require 'test/unit'
    Dir.glob(File.join(MulukhiyaTootProxy::Environment.dir, 'test/*')).each do |t|
      require t
    end
  end
end
