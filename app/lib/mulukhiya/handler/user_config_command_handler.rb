module Mulukhiya
  class UserConfigCommandHandler < CommandHandler
    def disable?
      return true unless Environment.dbms_class.config?
      return false
    end

    def handle_post_toot(body, params = {})
      super
      return unless parser.command_name == command_name
      notify(sns.account.user_config.to_h) if sns.account.user_config['/notify/user_config']
    end

    def exec
      raise Ginseng::AuthError, 'Unauthorized' unless sns.account
      if minutes = parser.params.dig('tagging', 'minutes')
        Sidekiq.set_schedule(
          "user_tag_initialize_#{sns.account.username}",
          create_schedule_params(minutes),
        )
        Sidekiq::Scheduler.reload_schedule!
        parser.params['tagging']['minutes'] = nil
      end
      sns.account.user_config.update(parser.params)
      sns.account.user_config.token = sns.token
    end

    private

    def create_schedule_params(minutes)
      return {
        at: (minutes + config['/tagging/user_tags/extra_minutes']).to_i.minutes.after,
        class: 'Mulukhiya::UserTagInitializeWorker',
        args: [{account: sns.account.id}],
      }
    end
  end
end
