module Mulukhiya
  extend Rake::DSL

  WIKI_URL = 'https://github.com/pooza/mulukhiya-toot-proxy/wiki/5.2.x-→-5.3-アップグレードガイド'.freeze

  DAEMON_DEPRECATION_ALL = <<~MSG.freeze
    rake %{action} は v5.3 で廃止されました。
    サービスマネージャ（systemd / rc.d）と競合し、プロセスの二重起動や
    ゾンビ化の原因となるためです。詳細: %{url}

    代わりに以下を実行してください:

    Ubuntu/RHEL (systemd):
      sudo systemctl %{action} mulukhiya-puma mulukhiya-sidekiq mulukhiya-listener

    FreeBSD (rc.d):
      sudo service mulukhiya-puma %{action}
      sudo service mulukhiya-sidekiq %{action}
      sudo service mulukhiya-listener %{action}
  MSG

  DAEMON_DEPRECATION_SINGLE = <<~MSG.freeze
    rake mulukhiya:%{daemon}:%{action} は v5.3 で廃止されました。
    サービスマネージャ（systemd / rc.d）と競合し、プロセスの二重起動や
    ゾンビ化の原因となるためです。詳細: %{url}

    代わりに以下を実行してください:

    Ubuntu/RHEL (systemd):
      sudo systemctl %{action} mulukhiya-%{daemon}

    FreeBSD (rc.d):
      sudo service mulukhiya-%{daemon} %{action}
  MSG

  namespace :mulukhiya do
    [:listener, :puma, :sidekiq].freeze.each do |daemon|
      namespace daemon do
        [:start, :stop, :restart].freeze.each do |action|
          desc "#{action} #{daemon} (deprecated)"
          task action do
            abort DAEMON_DEPRECATION_SINGLE % {daemon: daemon, action: action, url: WIKI_URL}
          end
        end
      end
    end
  end

  [:start, :stop, :restart].freeze.each do |action|
    desc "#{action} all (deprecated)"
    task action do
      abort DAEMON_DEPRECATION_ALL % {action: action, url: WIKI_URL}
    end
  end
end
