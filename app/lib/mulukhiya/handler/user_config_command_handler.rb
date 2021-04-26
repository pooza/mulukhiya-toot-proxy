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
      handle_user_tags(parser.params)
      sns.account.user_config.update(parser.params)
      sns.account.user_config.token = sns.token
    end

    private

    def handle_user_tags(params)
      return unless params['tagging'].is_a?(Hash)
      if minutes = params['tagging']['minutes']
        Sidekiq.set_schedule(task_name, create_schedule_params(minutes))
        params['tagging']['minutes'] = nil
      elsif params['tagging'].key?('user_tags') && params['tagging']['user_tags'].empty?
        Sidekiq.remove_schedule(task_name)
      end
      Sidekiq::Scheduler.reload_schedule!
    end

    def task_name
      return "user_tag_initialize_#{sns.account.username}"
    end

    def create_schedule_params(minutes)
      return {
        at: (minutes + config['/tagging/user_tags/extra_minutes']).to_i.minutes.after,
        class: 'Mulukhiya::UserTagInitializeWorker',
        args: [{account: sns.account.id}],
      }
    end
  end
end
