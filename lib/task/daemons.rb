namespace :mulukhiya do
  [:thin, :sidekiq].each do |ns|
    namespace ns do
      [:start, :stop].each do |action|
        desc "#{action} #{ns}"
        task action do
          sh "#{File.join(MulukhiyaTootProxy::Environment.dir, 'bin', "#{ns}_daemon.rb")} #{action}"
        rescue => e
          warn "#{e.class} #{ns}:#{action} #{e.message}"
        end
      end

      desc "restart #{ns}"
      task restart: [:stop, :start]
    end
  end
end
