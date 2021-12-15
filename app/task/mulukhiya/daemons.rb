module Mulukhiya
  extend Rake::DSL

  namespace :mulukhiya do
    [:listener, :puma, :sidekiq].freeze.each do |daemon|
      namespace daemon do
        desc "stop #{daemon}"
        task :stop do
          sh "#{File.join(Environment.dir, 'bin', "#{daemon}_daemon.rb")} stop"
        rescue => e
          warn "#{e.class} #{daemon}:stop #{e.message}"
        end

        desc "start #{daemon}"
        task start: ['mulukhiya:api:bundler', 'mulukhiya:feed:bundler'] do
          sh "#{File.join(Environment.dir, 'bin', "#{daemon}_daemon.rb")} start"
        rescue => e
          warn "#{e.class} #{daemon}:start #{e.message}"
        end

        desc "restart #{daemon}"
        task restart: ['config:lint', :stop, :start]
      end
    end
  end

  [:start, :stop, :restart].freeze.each do |action|
    desc "#{action} all"
    multitask action => Environment.task_prefixes.map {|v| "#{v}:#{action}"}
  end
end
