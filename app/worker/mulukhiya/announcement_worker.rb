module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
      @logger = Logger.new
    end

    def perform
      return unless executable?
      entries.each do |entry|
        next if cache.member?(entry['id'])
        parser = Environment.parser_class.new(entry['content'])
        agent.toot(parser.to_sanitized)
        agent.account.growi&.clip(parser.to_md)
      end
      save
    end

    private

    def entries
      @entries ||= announcements
      return @entries
    end

    def announcements
      return enum_for(__method__) unless block_given?
      agent.announcements.parsed_response.each do |announcement|
        yield announcement
      end
    end

    def cache
      return [] unless File.exist?(path)
      return JSON.parse(File.read(path))
    rescue => e
      Slack.broadcast(e)
      @logger.error(e)
    end

    alias load cache

    def save
      File.write(path, entries.to_h {|v| [v['id'], v]}.to_json)
    rescue => e
      Slack.broadcast(e)
      @logger.error(e)
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/announcements.json')
    end

    def executable?
      return Environment.controller_class.announcement?
    end

    def agent
      return Environment.info_agent
    end
  end
end
