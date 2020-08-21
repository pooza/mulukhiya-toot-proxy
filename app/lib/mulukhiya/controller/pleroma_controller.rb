module Mulukhiya
  class PleromaController < MastodonController
    post '/api/v1/media' do
      Handler.dispatch(:pre_upload, params, {reporter: @reporter, sns: @sns})
      @reporter.response = @sns.upload(params[:file][:tempfile].path, {
        filename: params[:file][:filename],
      })
      Handler.dispatch(:post_upload, params, {reporter: @reporter, sns: @sns})
      @renderer.message = JSON.parse(@reporter.response.body)
      @renderer.status = @reporter.response.code
      return @renderer.to_s
    rescue RestClient::Exception => e
      @renderer.message = e.response ? JSON.parse(e.response.body) : e.message
      notify(@renderer.message)
      @renderer.status = e.response&.code || 400
      return @renderer.to_s
    end

    def self.name
      return 'Pleroma'
    end

    def self.announcement?
      return false
    end

    def self.filter?
      return false
    end

    def self.livecure?
      return false
    end

    def self.tag_feed?
      return false
    end

    def self.parser_class
      return "Mulukhiya::#{parser_name.camelize}Parser".constantize
    end

    def self.dbms_class
      return "Mulukhiya::#{dbms_name.camelize}".constantize
    end

    def self.postgres?
      return dbms_name == 'postgres'
    end

    def self.mongo?
      return dbms_name == 'mongo'
    end

    def self.dbms_name
      return config['/pleroma/dbms']
    end

    def self.parser_name
      return config['/pleroma/parser']
    end

    def self.status_field
      return config['/parser/toot/fields/body']
    end

    def self.status_key
      return config['/pleroma/status/key']
    end

    def self.poll_options_field
      return config['/parser/toot/fields/poll/options']
    end

    def self.spoiler_field
      return config['/parser/toot/fields/spoiler']
    end

    def self.attachment_field
      return config['/parser/toot/fields/attachment']
    end

    def self.visibility_name(name)
      return parser_class.visibility_name(name)
    end

    def self.status_label
      return config['/pleroma/status/label']
    end

    def self.events
      return config['/pleroma/events'].map(&:to_sym)
    end

    def self.webhook_entries
      return enum_for(__method__) unless block_given?
      Pleroma::AccessToken.order(Sequel.desc(:inserted_at)).all do |token|
        yield token.to_h if token.valid?
      end
    end
  end
end
