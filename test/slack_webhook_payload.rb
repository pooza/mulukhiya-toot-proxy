module Mulukhiya
  class SlackWebhookPayloadTest < TestCase
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

      @growi = SlackWebhookPayload.new(%({
        "response_type": "ephemeral",
        "channel": "#test",
        "text": ":bell: <https://mulukhiya.growi.cloud/user/pooza|pooza> created <https://mulukhiya.growi.cloud/mulukhiya/user/pooza/2020/09/12/135825|/mulukhiya/user/pooza/2020/09/12/135825>",
        "username": "GROWI",
        "attachments": [
          {
            "color": "#263a3c",
            "text": "",
            "mrkdwn_in": [
              "text"
            ]
          }
        ],
        "link_names": 0,
        "icon_emoji": ""
      }))
    end

    def test_blocks?
      assert_false(@normal.blocks?)
      assert(@blocks.blocks?)
      assert_false(@growi.blocks?)
    end

    def test_attachments?
      assert(@normal.attachments?)
      assert_false(@blocks.attachments?)
      assert(@growi.attachments?)
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
      assert_equal(@growi.text, '🔔 [ pooza ](https://mulukhiya.growi.cloud/user/pooza) created [ /mulukhiya/user/pooza/2020/09/12/135825 ](https://mulukhiya.growi.cloud/mulukhiya/user/pooza/2020/09/12/135825)')
    end

    def test_images
      assert_kind_of(Array, @normal.images)
      assert_kind_of(Array, @blocks.images)
      assert_kind_of(Array, @growi.images)
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
