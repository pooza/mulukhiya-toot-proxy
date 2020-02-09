require 'time'

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
        agent.toot(create_body(entry, :sanitized))
        agent.account.growi&.clip(create_body(entry, :md))
        sleep(1)
      end
      save
    end

    private

    def create_body(entry, format = :text)
      parser = Environment.parser_class.new(entry['content'])
      template = Template.new('announcement')
      template[:body] = parser.send("to_#{format}".to_sym)
      if entry['starts_at'] && entry['ends_at']
        template[:start_date] = Time.parse(entry['starts_at'])
        template[:end_date] = Time.parse(entry['ends_at'])
        template[:all_day] = entry['all_day']
      end
      return template.to_s
    end

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
      return {} unless File.exist?(path)
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
