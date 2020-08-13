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
          top_record = nil
          account.annict.recent_records do |record|
            top_record ||= record
            account.webhook.post(create_body(record))
          end
          account.annict.updated_at = top_record['created_at'] if top_record
        elsif top_record = account.annict.updated_at = account.annict.records.first
          account.annict.updated_at = top_record['created_at']
        end
      end
    end

    def accounts
      return enum_for(__method__) unless block_given?
      @storage.account_ids do |id|
        yield Environment.account_class[id]
      end
    end

    def create_body(record)
      template = Template.new('annict_record')
      template[:record] = record.deep_stringify_keys
      body = {'text' => template.to_s, 'attachments' => []}
      uri = Ginseng::URI.parse(template[:record].dig('work', 'images', 'recommended_url'))
      body['attachments'].push({'image_url' => uri.to_s}) if uri&.absolute?
      return body
    end
  end
end
