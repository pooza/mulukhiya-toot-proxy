module Mulukhiya
  # Akkoma（Pleroma 系）のコントローラ（#4566）。API はほぼ Mastodon 互換なので
  # `MastodonController` を継承し、Pleroma 固有の口（絵文字リアクション）だけを足す。
  # ⚠ 名前は `pleroma`（2026-10-16 ユーザー判断）。gem の `PleromaService` と揃え、
  # Akkoma も `/api/v1/pleroma/*` を保っている。
  class PleromaController < MastodonController
    put '/api/:version/pleroma/statuses/:status_id/reactions/:emoji' do
      verify_token_integrity!
      reporter.response = sns.reaction(params[:status_id], params[:emoji])
      Event.new(:post_reaction, {reporter:, sns:}).dispatch(params)
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e)
      return @renderer.to_s
    end

    delete '/api/:version/pleroma/statuses/:status_id/reactions/:emoji' do
      verify_token_integrity!
      reporter.response = sns.delete_reaction(params[:status_id], params[:emoji])
      @renderer.message = reporter.response.parsed_response
      @renderer.status = reporter.response.code
      return @renderer.to_s
    rescue Ginseng::GatewayError => e
      handle_gateway_error(e)
      return @renderer.to_s
    end
  end
end
