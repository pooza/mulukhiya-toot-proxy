require 'time'

module Mulukhiya
  class AnnictPollingWorker
    include Sidekiq::Worker

    def initialize
      @config = Config.instance
      @logger = Logger.new
      @storage = AnnictStorage.new
    end

    def perform
      accounts do |account|
        next unless account.webhook
        next unless account.annict
        if account.annict.updated_at
          perform_account(account)
        elsif top_record = account.annict.updated_at = account.annict.records.first
          account.annict.updated_at = top_record['created_at']
        end
      end
    end

    def perform_account(account)
      account.annict.recent_records do |record|
        self.time = record['created_at']
        account.webhook.post(create_body(record, :record))
      end
      account.annict.recent_reviews do |review|
        self.time = review['created_at']
        account.webhook.post(create_body(review, :review))
      end
      account.annict.updated_at = time if time
    end

    def time
      return @time
    end

    def time=(time)
      time = Time.parse(time)
      return if @time && time < @time
      @time = time
    end

    def accounts
      return enum_for(__method__) unless block_given?
      @storage.account_ids do |id|
        yield Environment.account_class[id]
      end
    end

    def create_body(values, type)
      template = Template.new("annict_#{type}")
      template[type] = values.deep_stringify_keys
      body = {'text' => template.to_s, 'attachments' => []}
      uri = Ginseng::URI.parse(template[type].dig('work', 'images', 'recommended_url'))
      body['attachments'].push({'image_url' => uri.to_s}) if uri&.absolute?
      return body
    end
  end
end
