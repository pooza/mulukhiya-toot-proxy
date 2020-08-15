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
      @growi ||= GrowiClipper.create(account_id: id)
      return @growi
    rescue => e
      logger.error(e)
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
      if annict.updated_at
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
      elsif top_record = annict.records.first
        annict.updated_at = top_record['created_at']
      end
    end

    def twitter
      unless @twitter
        return nil unless config['/twitter/token']
        return nil unless config['/twitter/secret']
        @twitter = TwitterService.new do |twitter|
          twitter.consumer_key = TwitterService.consumer_key
          twitter.consumer_secret = TwitterService.consumer_secret
          twitter.access_token = config['/twitter/token']
          twitter.access_token_secret = config['/twitter/secret']
        end
      end
      return @twitter
    rescue => e
      logger.error(e)
      return nil
    end

    def notify_verbose?
      return config['/notify/verbose'] == true
    end

    def disable?(handler_name)
      return true if config["/handler/#{handler_name}/disable"]
      return false
    end

    def tags
      return config['/tags'] || []
    end
  end
end
