module Mulukhiya
  # Akkoma（Pleroma 系）の添付の参照（段階 3 の残り・#4861）。⚠ Akkoma の DB とテスト用アカウントが要る。
  class PleromaAttachmentTest < TestCase
    def disable?
      return true unless Environment.pleroma?
      return true unless account
      return super
    end

    # 投稿の `media_ids`（API のメディア ID）を `attachment_class[id]` で引く経路（`MediaTagHandler`・
    # `Handler#flatten_payload`）。⚠ Akkoma の API のメディア ID は `objects` の主キーと同じ。
    def upload
      return account.service.upload(File.join(Environment.dir, 'test/fixture/sample.jpg'), {response: :id})
    end

    def test_get_by_api_id
      attachment = attachment_class[upload]

      assert_kind_of(Pleroma::Attachment, attachment)
      assert(attachment.type.start_with?('image/'))
      assert_predicate(attachment.name, :present?)
      assert_equal(account.uri.to_s, attachment.data[:actor])
    end

    # ⚠ 上げたばかりの 1 枚が先頭に来ることを見る（以前は常に `[]` を返していた）。
    def test_attachments
      id = upload
      attachments = account.attachments
      attachment = attachments.first

      assert_kind_of(Pleroma::Attachment, attachment)
      assert_equal(id.to_s, attachment.id.to_s)
      assert_equal('Document', attachment.data[:type])
      assert_equal(account.uri.to_s, attachment.data[:actor])
      assert_kind_of(Integer, attachments.count)
      # 新しい順。
      ids = attachments.first(2).map(&:id)

      assert_equal(ids.sort.reverse, ids)
    end

    # メディアカタログ（段階 5・#4911）。⚠ URL は `/notice/<FlakeId>`。
    # ⚠ テスト用アカウントの投稿はカタログから外す（Mastodon・Misskey と同じ）ので、並ばないことを見る。
    def test_catalog
      id = upload
      response = account.service.post({status: "メディアカタログ #4911 #{Time.now.to_i}", media_ids: [id], visibility: 'public'})

      assert_equal(200, response.code)
      items = attachment_class.catalog(skip_cache: true, limit: 100)[:items]

      assert_not_include(items.map {|v| v[:id].to_s}, id.to_s)
      items.each do |item|
        assert_match(%r{/notice/[0-9A-Za-z]+\z}, item.dig(:status, :public_url))
        assert_match(%r{/mulukhiya/app/status/[0-9A-Za-z]+\z}, item.dig(:status, :webui_url))
        assert_nil(item[:data])
      end
    end

    # ⚠⚠ cursor で辿った並びと、ページで送った並びが一致すること（境目の添付が抜けない・#4375）。
    def test_catalog_paging
      full = attachment_class.catalog(skip_cache: true, limit: 100)[:items].map {|v| v[:id]}
      by_cursor = []
      cursor = nil
      20.times do
        result = attachment_class.catalog({skip_cache: true, limit: 3}.merge(cursor ? {cursor:} : {}))
        by_cursor.concat(result[:items].map {|v| v[:id]})
        break unless result[:has_next]
        cursor = result[:next_cursor]

        assert_true(MediaListContract.pleroma_cursor?(cursor))
      end

      assert_equal(full.first(by_cursor.size), by_cursor)
    end
  end
end
