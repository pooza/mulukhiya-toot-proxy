module Mulukhiya
  class GitHubWebhookPayload
    include Package
    attr_reader :raw

    def initialize(values)
      @raw = JSON.parse(values) unless values.is_a?(Hash)
      @raw ||= values.deep_stringify_keys
    end

    def errors
      @errors ||= GitHubWebhookContract.new.exec(@raw)
      return @errors
    end

    def action
      return @raw['action']
    end

    def zen
      return @raw['zen']
    end

    def ref
      return @raw['ref']
    end

    def after
      return @raw['after']
    end

    def check_suite
      return {
        conclusion: @raw.dig('check_suite', 'conclusion'),
        url: @raw.dig('check_suite', 'html_url'),
      }
    end

    def check_run
      return {
        conclusion: @raw.dig('check_run', 'conclusion'),
        url: @raw.dig('check_run', 'html_url'),
      }
    end

    def repository
      return {
        name: @raw.dig('repository', 'full_name'),
        url: @raw.dig('repository', 'html_url'),
      }
    end

    def issue
      return {
        title: @raw.dig('issue', 'title'),
        url: @raw.dig('issue', 'html_url'),
        milestone: @raw.dig('issue', 'milestone', 'title'),
      }
    end

    def values
      return {
        Environment.controller_class.status_field => {
          zen: zen,
          action: action,
          ref: ref,
          after: after,
          check_suite: check_suite,
          check_run: check_run,
          repository: repository,
          issue: issue,
        }.deep_stringify_keys.deep_compact.to_yaml,
      }
    end

    alias to_h values
  end
end
