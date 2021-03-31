namespace :mulukhiya do
  [:listener, :puma, :sidekiq].freeze.each do |daemon|
    namespace daemon do
      [:start, :stop].freeze.each do |action|
        desc "#{action} #{daemon}"
        task action do
          sh "#{File.join(Mulukhiya::Environment.dir, 'bin', "#{daemon}_daemon.rb")} #{action}"
        rescue => e
          warn "#{e.class} #{daemon}:#{action} #{e.message}"
        end
      end

      desc "restart #{daemon}"
      task restart: [:stop, :start]
    end
  end
end

[:start, :stop, :restart].freeze.each do |action|
  desc "#{action} all"
  multitask action => Mulukhiya::Environment.task_prefixes.map {|v| "#{v}:#{action}"}
end
