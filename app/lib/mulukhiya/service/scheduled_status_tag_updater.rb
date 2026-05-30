module Mulukhiya
  # 予約投稿のフッタータグを書き換える。Mastodon の予約投稿は本文の部分更新が
  # できないため、元の予約を削除し、タグを差し替えた本文で予約を作り直す。
  # 作り直しに失敗したときは元の本文で予約を復元する (ロールバック)。
  # 切り出し元は APIController PUT /scheduled_status/:id/tags (#4285)。
  class ScheduledStatusTagUpdater
    include Package

    def initialize(sns, storage = ScheduledStatusStorage.new)
      @sns = sns
      @storage = storage
    end

    def call(id, entry, tags)
      saved_params = entry[:params].deep_stringify_keys
      original_body = saved_params[field]
      saved_params[field] = rewrite_body(original_body, tags)
      delete_scheduled_status!(id)
      response = @sns.toot(recreate_params(saved_params, entry))
      unless success?(response)
        rollback(saved_params, original_body, entry)
        raise Ginseng::GatewayError, response.parsed_response['error'] || 'recreate failed'
      end
      new_entry = response.parsed_response
      @storage.unlink(id)
      store(new_entry, saved_params)
      return {
        id: new_entry['id'],
        scheduled_at: new_entry['scheduled_at'],
        tags:,
      }
    end

    private

    def field
      return @sns.status_field
    end

    def rewrite_body(body, tags)
      parser = @sns.parser_class.new(body)
      return [
        parser.body,
        '',
        tags.map(&:to_hashtag).join(' '),
      ].join("\n")
    end

    def delete_scheduled_status!(id)
      response = @sns.delete_scheduled_status(id)
      return if success?(response)
      raise Ginseng::GatewayError, response.parsed_response&.dig('error') || 'delete failed'
    end

    def rollback(saved_params, original_body, entry)
      saved_params[field] = original_body
      @sns.toot(recreate_params(saved_params, entry))
    end

    def store(new_entry, saved_params)
      margin = ScheduledStatusSaveHandler::MARGIN
      expires_in = (Time.parse(new_entry['scheduled_at']) - Time.now).to_i
      ttl = [expires_in + margin, margin].max
      @storage.set(new_entry['id'], {
        account_id: @sns.account.id,
        params: saved_params,
        scheduled_at: new_entry['scheduled_at'],
      }, ttl:)
    end

    def recreate_params(saved_params, entry)
      return saved_params.merge('scheduled_at' => entry[:scheduled_at]).compact
    end

    def success?(response)
      return response.code.between?(200, 299)
    end
  end
end
