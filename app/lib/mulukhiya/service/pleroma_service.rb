module Mulukhiya
  # Akkoma（Pleroma 系）のサービス（#4566）。API はほぼ Mastodon 互換なので、モロヘイヤの
  # `MastodonService` を継承して差分だけを持つ（v4 は gem の `PleromaService` を継承していたが、
  # そちらは 2024-09 から追随していない）。
  class PleromaService < MastodonService
    def theme_color
      return config['/pleroma/theme/color']
    end

    def oauth_controller_class
      return PleromaController
    end

    # ⚠ 上限は NodeInfo（`info`）ではなく `GET /api/v1/instance` にある（PR #4844 の Codex P2）。
    def instance
      @instance ||= http.get('/api/v1/instance').parsed_response.to_h
      return @instance
    end

    def max_post_text_length
      length = instance['max_toot_chars']
      length ||= instance.dig('configuration', 'statuses', 'max_characters')
      return length || config['/pleroma/status/default_max_length']
    rescue => e
      e.log
      return config['/pleroma/status/default_max_length']
    end

    def max_media_attachments
      limit = instance.dig('configuration', 'statuses', 'max_media_attachments')
      return limit || config['/pleroma/attachment/limit']
    rescue => e
      e.log
      return config['/pleroma/attachment/limit']
    end

    def reaction(id, emoji, params = {})
      return http.put("/api/v1/pleroma/statuses/#{id}/reactions/#{emoji}", {
        headers: create_headers(params[:headers]),
      })
    end

    def delete_reaction(id, emoji, params = {})
      return http.delete("/api/v1/pleroma/statuses/#{id}/reactions/#{emoji}", {
        headers: create_headers(params[:headers]),
      })
    end

    def search_status_id(status)
      case status
      in Pleroma::Status
        return status.id
      in Ginseng::URI
        return status.path.match(%r{/notice/([^/]+)})&.[](1) || super
      else
        return super
      end
    end

    def default_uri
      return URI.parse(config['/pleroma/url'])
    end
  end
end
