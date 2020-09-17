require 'time'
require 'digest/sha1'

module Mulukhiya
  class AnnouncementWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
      @logger = Logger.new
      @sns = Environment.info_agent_service
    end

    def perform
      return unless executable?
      @sns.announcements.each do |entry|
        next if cache.member?(entry[:id])
        Handler.dispatch(:announce, entry, {sns: @sns})
        sleep(1)
      end
      save
    end

    private

    def cache
      return {} unless File.exist?(path)
      return JSON.parse(File.read(path))
    rescue => e
      @logger.error(e)
    end

    def save
      File.write(path, @sns.announcements.to_h {|v| [v[:id], v]}.to_json)
    rescue => e
      @logger.error(e)
    end

    def path
      return File.join(Environment.dir, 'tmp/cache/announcements.json')
    end

    def executable?
      return Environment.controller_class.announcement?
    end
  end
end
