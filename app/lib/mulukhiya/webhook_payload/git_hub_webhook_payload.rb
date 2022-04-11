module Mulukhiya
  class GitHubWebhookPayload < WebhookPayload
    def contract
      @contract ||= GitHubWebhookContract.new.exec(raw) if raw
      return @contract
    end

    def check_suite
      return {
        conclusion: raw.dig('check_suite', 'conclusion'),
        url: raw.dig('check_suite', 'html_url'),
      }
    end

    def check_run
      return {
        conclusion: raw.dig('check_run', 'conclusion'),
        url: raw.dig('check_run', 'html_url'),
      }
    end

    def repository
      return {
        name: raw.dig('repository', 'full_name'),
        url: raw.dig('repository', 'html_url'),
      }
    end

    def issue
      return {
        title: raw.dig('issue', 'title'),
        url: raw.dig('issue', 'html_url'),
        milestone: raw.dig('issue', 'milestone', 'title'),
      }
    end

    def milestone
      return {
        title: raw.dig('milestone', 'title'),
        url: raw.dig('milestone', 'html_url'),
      }
    end

    def head_commit
      return {
        message: raw.dig('head_commit', 'message'),
        url: raw.dig('head_commit', 'url'),
      }
    end

    def values
      return {
        status_field => {
          zen:,
          action:,
          ref:,
          after:,
          check_suite:,
          check_run:,
          repository:,
          issue:,
          milestone:,
          head_commit:,
        }.deep_compact.to_yaml,
      }
    end

    alias to_h values
  end
end
