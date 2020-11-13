require 'time'

module Mulukhiya
  module AccountMethods
    def logger
      @logger ||= Logger.new
      return @logger
    end

    def config
      @config ||= UserConfig.new(id)
      return @config
    end

    def webhook
      return Webhook.new(config)
    rescue => e
      logger.error(e)
      return nil
    end

    def growi
      unless @growi
        raise Ginseng::ConfigError, '/growi/url undefined' unless config['/growi/url']
        raise Ginseng::ConfigError, '/growi/token undefined' unless config['/growi/token']
        @growi = GrowiClipper.new(
          uri: config['/growi/url'],
          token: config['/growi/token'],
          prefix: config['/growi/prefix'] || File.join('/', Package.short_name, 'user', username),
        )
      end
      return @growi
    rescue => e
      logger.error(clipper: self.class.to_s, error: e.message, acct: acct.to_s)
      return nil
    end

    def dropbox
      @dropbox ||= DropboxClipper.create(account_id: id)
      return @dropbox
    rescue => e
      logger.error(e)
      return nil
    end

    def annict
      return nil unless config['/annict/token'].present?
      @annict ||= AnnictService.new(config['/annict/token'])
      return @annict
    end

    def crawl_annict
      annict.updated_at ||= Time.now
      times = []
      annict.recent_records do |record|
        times.push(Time.parse(record['created_at']))
        webhook.post(annict.create_body(record, :record))
      end
      annict.recent_reviews do |review|
        times.push(Time.parse(review['created_at']))
        webhook.post(annict.create_body(review, :review))
      end
      annict.updated_at = times.max if times.present?
    end

    def notify_verbose?
      return config['/notify/verbose'] == true
    end

    def tags
      return config['/tags'] || []
    end
  end
end
