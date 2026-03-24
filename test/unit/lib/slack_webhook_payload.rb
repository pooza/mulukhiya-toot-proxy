module Mulukhiya
  class SlackWebhookPayloadTest < TestCase
    def disable?
      return true unless SlackService.config?
      return super
    end

    def setup
      @normal = SlackWebhookPayload.new(%({
        "spoiler_text": "ネタバレ注意1",
        "text": "1: つかみ男につかまれると、体力ゲージが減少していく。",
        "attachments": [
          {
            "image_url": "https://image.example.com/image1a.png"
          },
          {
            "image_url": "https://image.example.com/image1b.png"
          }
        ]
      }))

      @blocks = SlackWebhookPayload.new(%({
        "blocks": [
          {
            "type": "header",
            "text": {
              "type": "plain_text",
              "text": "ネタバレ注意2"
            }
          },
          {
            "type": "section",
            "text": {
              "type": "plain_text",
              "text": "2: つかみ男につかまれると、体力ゲージが減少していく。"
            }
          },
          {
            "type": "image",
            "image_url": "https://image.example.com/image2a.png",
            "alt_text": "title image"
          },
          {
            "type": "image",
            "image_url": "https://image.example.com/image2b.png",
            "alt_text": "title image"
          }
        ]
      }))

      @attachments_rich = SlackWebhookPayload.new(%({
        "text": "本文",
        "attachments": [
          {
            "pretext": "前置き",
            "author_name": "著者",
            "author_link": "https://example.com/author",
            "title": "タイトル",
            "title_link": "https://example.com/article",
            "text": "添付テキスト",
            "fields": [
              {"title": "状態", "value": "OK"},
              {"title": "件数", "value": "42"}
            ],
            "footer": "フッター",
            "image_url": "https://image.example.com/main.png",
            "thumb_url": "https://image.example.com/thumb.png"
          }
        ]
      }))

      @context_blocks = SlackWebhookPayload.new(%({
        "blocks": [
          {
            "type": "section",
            "text": {"type": "mrkdwn", "text": "セクション本文"}
          },
          {
            "type": "context",
            "elements": [
              {"type": "mrkdwn", "text": "コンテキスト1"},
              {"type": "mrkdwn", "text": "コンテキスト2"}
            ]
          }
        ]
      }))

      @rich_text_blocks = SlackWebhookPayload.new(%({
        "blocks": [
          {
            "type": "rich_text",
            "elements": [
              {
                "type": "rich_text_section",
                "elements": [
                  {"type": "text", "text": "リッチ"},
                  {"type": "text", "text": "テキスト"}
                ]
              }
            ]
          }
        ]
      }))
    end

    def test_blocks?
      assert_false(@normal.blocks?)
      assert_predicate(@blocks, :blocks?)
    end

    def test_attachments?
      assert_predicate(@normal, :attachments?)
      assert_false(@blocks.attachments?)
    end

    def test_header
      assert_equal('ネタバレ注意1', @normal.header)
      assert_equal('ネタバレ注意2', @blocks.header)
      assert_equal('ネタバレ注意1', @normal.spoiler_text)
      assert_equal('ネタバレ注意2', @blocks.spoiler_text)
    end

    def test_text
      assert_equal('1: つかみ男につかまれると、体力ゲージが減少していく。', @normal.text)
      assert_equal('2: つかみ男につかまれると、体力ゲージが減少していく。', @blocks.text)
    end

    def test_text_with_attachments
      text = @attachments_rich.text

      assert_includes(text, '本文')
      assert_includes(text, '前置き')
      assert_includes(text, '[著者](https://example.com/author)')
      assert_includes(text, '[タイトル](https://example.com/article)')
      assert_includes(text, '添付テキスト')
      assert_includes(text, '**状態**: OK')
      assert_includes(text, '**件数**: 42')
      assert_includes(text, 'フッター')
    end

    def test_text_context_blocks
      text = @context_blocks.text

      assert_includes(text, 'セクション本文')
      assert_includes(text, 'コンテキスト1')
      assert_includes(text, 'コンテキスト2')
    end

    def test_text_rich_text_blocks
      text = @rich_text_blocks.text

      assert_includes(text, 'リッチテキスト')
    end

    def test_images
      assert_kind_of(Array, @normal.images)
      assert_kind_of(Array, @blocks.images)
    end

    def test_images_with_thumb_url
      images = @attachments_rich.images
      uris = images.map {|v| v['image_url']}

      assert_includes(uris, 'https://image.example.com/main.png')
      assert_includes(uris, 'https://image.example.com/thumb.png')
    end

    def test_image_uris
      assert_kind_of(Array, @normal.image_uris)
      @normal.image_uris.each do |uri|
        assert_kind_of(Ginseng::URI, uri)
        assert_predicate(uri, :absolute?)
      end

      assert_kind_of(Array, @blocks.image_uris)
      @blocks.image_uris.each do |uri|
        assert_kind_of(Ginseng::URI, uri)
        assert_predicate(uri, :absolute?)
      end
    end
  end
end
