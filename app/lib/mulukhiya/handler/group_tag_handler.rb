module Mulukhiya
  class GroupTagHandler < TagHandler
    CACHE_KEY = 'group_tag:communities'.freeze

    def disable?
      return true unless sources.present?
      return super
    end

    def addition_tags
      tags = TagContainer.new
      map = community_map
      parser.accts.each do |acct|
        entry = map[acct.to_s] || map[acct.to_s.delete_prefix('@')]
        tags.concat(entry[:hashtags]) if entry
        tags.push(db_display_name(acct)) if mastodon?
      end
      return tags
    end

    private

    def community_map
      update_cache unless cache_valid?
      return @community_map ||= load_cache
    end

    def update_cache
      communities = []
      sources.each do |url|
        response = @http.get(url)
        data = response.parsed_response
        communities.concat(data['communities'] || [])
      rescue => e
        e.log(url:)
      end
      @community_map = build_map(communities)
      redis.setex(CACHE_KEY, cache_ttl, communities.to_json)
    end

    def load_cache
      raw = redis[CACHE_KEY]
      return {} unless raw
      return build_map(JSON.parse(raw))
    rescue => e
      e.log
      return {}
    end

    def build_map(communities)
      map = {}
      communities.each do |entry|
        acct = entry['acct'].to_s
        map[acct] = {hashtags: entry['hashtags'] || []}
      end
      return map
    end

    def cache_valid?
      return redis.key?(CACHE_KEY)
    end

    def cache_ttl
      return handler_config(:cache_ttl) || 3600
    end

    def sources
      return handler_config(:sources) || []
    end

    def db_display_name(acct)
      account = account_class.get(acct: acct)
      return nil unless account
      return nil unless account.actor_type == 'Group'
      return account.values[:display_name].presence
    rescue
      return nil
    end

    def mastodon?
      return controller_class == MastodonController
    rescue
      return false
    end

    def redis
      @redis ||= Redis.new
      return @redis
    end

    def initialize(params = {})
      super
      @http = HTTP.new
    end
  end
end
