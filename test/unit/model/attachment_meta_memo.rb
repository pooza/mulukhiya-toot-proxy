module Mulukhiya
  # 添付のメタデータは項目ごとに 1 回だけ引き、ストレージはプロセスで使い回す (#4920)。
  #
  # ⚠ Pleroma 系は `meta` を上書きしないので、`to_h` の `size`・`pixel_size`・`duration` が
  # そのたびにストレージ（Redis の接続プールと `HTTP`）を作り直していた。DB 非依存で本体を踏む。
  class AttachmentMetaMemoTest < TestCase
    URL = 'https://media.test/memo.mp4'.freeze

    class FakeStorage
      attr_reader :calls

      def initialize
        @calls = []
      end

      def key?(uri)
        @calls.push(:key?)
        return false
      end

      def push(uri)
        @calls.push(:push)
      end

      def [](uri)
        @calls.push(:get)
        return {width: 640, height: 360, duration: 12.345, size: 1024}
      end
    end

    class FakeAttachment
      include AttachmentMethods

      def id = 1
      def type = 'video/mp4'
      def create_uri(_size = :original) = Ginseng::URI.parse(URL)
    end

    def setup
      @storage = FakeStorage.new
      storage = @storage
      AttachmentMethods.singleton_class.alias_method(:__orig_storage, :media_metadata_storage)
      AttachmentMethods.define_singleton_method(:media_metadata_storage) {storage}
    end

    def teardown
      AttachmentMethods.singleton_class.alias_method(:media_metadata_storage, :__orig_storage)
      AttachmentMethods.singleton_class.remove_method(:__orig_storage)
      super
    end

    def test_meta_is_fetched_once
      attachment = FakeAttachment.new

      assert_equal('640x360', attachment.pixel_size)
      assert_in_delta(12.35, attachment.duration)
      assert_equal(640, attachment.width)
      assert_equal([:key?, :push, :get], @storage.calls)
    end

    # 取れなかったことも覚える。項目ごとに何度も取りに行かない。
    def test_failure_is_memoized
      @storage.define_singleton_method(:[]) {|_uri| raise 'broken'}
      attachment = FakeAttachment.new

      assert_nil(attachment.pixel_size)
      assert_nil(attachment.duration)
      assert_equal([:key?, :push], @storage.calls)
    end

    def test_storage_is_shared
      AttachmentMethods.singleton_class.alias_method(:media_metadata_storage, :__orig_storage)
      first = AttachmentMethods.media_metadata_storage

      assert_kind_of(MediaMetadataStorage, first)
      assert_same(first, AttachmentMethods.media_metadata_storage)
    ensure
      storage = @storage
      AttachmentMethods.define_singleton_method(:media_metadata_storage) {storage}
    end
  end
end
