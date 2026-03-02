module Mulukhiya
  extend Rake::DSL

  DAEMON_DEPRECATION = <<~MSG.freeze
    rake %{action} は廃止されました。サービスマネージャ経由で操作してください。

    Ubuntu/RHEL:
      sudo systemctl %{action} mulukhiya-puma mulukhiya-sidekiq mulukhiya-listener

    FreeBSD:
      sudo service mulukhiya-puma %{action}
      sudo service mulukhiya-sidekiq %{action}
      sudo service mulukhiya-listener %{action}
  MSG

  namespace :mulukhiya do
    [:listener, :puma, :sidekiq].freeze.each do |daemon|
      namespace daemon do
        [:start, :stop, :restart].freeze.each do |action|
          desc "#{action} #{daemon} (deprecated)"
          task action do
            abort DAEMON_DEPRECATION % {action: action}
          end
        end
      end
    end
  end

  [:start, :stop, :restart].freeze.each do |action|
    desc "#{action} all (deprecated)"
    task action do
      abort DAEMON_DEPRECATION % {action: action}
    end
  end
end
