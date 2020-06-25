module Mulukhiya
  module Pleroma
    class Status < Sequel::Model(:objects)
      def account
        return Account.first(ap_id: data['actor'])
      end

      def context_id
        return data['context_id'].to_i
      end

      def text
        return data['content']
      end

      def to_md
        template = Template.new('toot_clipping.md')
        template[:account] = account.to_h
        template[:status] = TootParser.new(data['content']).to_md
        template[:url] = uri.to_s
        return template.to_s
      end

      def uri
        @uri ||= Ginseng::URI.parse(data['context'])
        return @uri
      end

      def attachments
        return []
      end

      def data
        @data ||= JSON.parse(values[:data])
        return @data
      end

      def to_h
        @hash = data.clone
        @hash['url'] = uri.to_s
        @hash['account'] = account.to_h
        return @hash
      end

      def self.[](id)
        record = super
        rows = Postgres.instance.exec('recent_status', {context_id: record.context_id})
        return Status.first(id: rows.first['id']) if rows.present?
        return nil
      end
    end
  end
end
