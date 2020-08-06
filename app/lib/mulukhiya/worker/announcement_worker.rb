require 'time'
require 'digest/sha1'

module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
      @logger = Logger.new
    end

    def perform
      return unless executable?
      announcements.each do |entry|
        next if cache.member?(entry['id'])
        service.post(
          Environment.controller_class.status_field => create_body(entry, :sanitized),
          'visibility' => Environment.controller_class.visibility_name('unlisted'),
        )
        service.account.growi&.clip(create_body(entry, :md))
        if dir = clipping_dir
          clip_local_file(dir, entry)
        end
        sleep(1)
      end
      save
    end

    def announcements(&block)
      return enum_for(__method__) unless block_given?
      service.announcements.each(&block)
    end

    private

    def create_body(entry, format = :text)
      parser = Environment.parser_class.new(entry['content'] || entry['text'])
      template = Template.new('announcement')
      template[:body] = parser.send("to_#{format}".to_sym)
      template[:title] = entry['title']
      template[:image_url] = entry['imageUrl']
      if entry['starts_at'] && entry['ends_at']
        template[:start_date] = Time.parse(entry['starts_at'])
        template[:end_date] = Time.parse(entry['ends_at'])
        template[:all_day] = entry['all_day']
      end
      return template.to_s
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
      File.write(path, announcements.to_h {|v| [v['id'], v]}.to_json)
    rescue => e
      Slack.broadcast(e)
      @logger.error(e)
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/announcements.json')
    end

    def clip_local_file(dir, entry)
      basename = entry[:title] || Digest::SHA1.hexdigest(entry.to_json)
      path = File.join(dir, "#{Date.today.strftime('%Y%m%d')}#{basename}.md")
      File.write(path, create_body(entry, :md))
      @logger.info(worker: self.class.to_s, entry: entry)
    rescue => e
      @logger.error(worker: self.class.to_s, error: e.message, entry: entry)
    end

    def clipping_dir
      return nil unless @config['/worker/announcement/local_clipping/enable']
      return nil unless path = @config['/worker/announcement/local_clipping/path']
      path = File.join(Environment.dir, path) unless path.start_with?('/')
      return path
    end

    def executable?
      return Environment.controller_class.announcement?
    end

    def service
      return Environment.info_agent_service
    end
  end
end
