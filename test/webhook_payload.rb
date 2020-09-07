module Mulukhiya
  class WebhookPayloadTest < TestCase
    def setup
      @normal = WebhookPayload.new(%({
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

      @blocks = WebhookPayload.new(%({
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
      assert(@blocks.blocks?)
    end

    def test_header
      assert_equal(@normal.header, 'ネタバレ注意1')
      assert_equal(@blocks.header, 'ネタバレ注意2')
      assert_equal(@normal.spoiler_text, 'ネタバレ注意1')
      assert_equal(@blocks.spoiler_text, 'ネタバレ注意2')
    end

    def test_text
      assert_equal(@normal.text, '1: つかみ男につかまれると、体力ゲージが減少していく。')
      assert_equal(@blocks.text, '2: つかみ男につかまれると、体力ゲージが減少していく。')
    end

    def test_images
      assert_kind_of(Array, @normal.images)
      assert_kind_of(Array, @blocks.images)
    end

    def test_image_uris
      assert_kind_of(Array, @normal.image_uris)
      @normal.image_uris.each do |uri|
        assert_kind_of(Ginseng::URI, uri)
        assert(uri.absolute?)
      end

      assert_kind_of(Array, @blocks.image_uris)
      @blocks.image_uris.each do |uri|
        assert_kind_of(Ginseng::URI, uri)
        assert(uri.absolute?)
      end
    end
  end
end
