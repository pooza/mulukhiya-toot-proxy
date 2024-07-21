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

    def test_images
      assert_kind_of(Array, @normal.images)
      assert_kind_of(Array, @blocks.images)
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
