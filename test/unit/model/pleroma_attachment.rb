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
  end
end
