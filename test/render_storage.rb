module Mulukhiya
  class RenderStorageTest < TestCase
    def setup
      @storage = RenderStorage.new
      @renderer = RSS20FeedRenderer.new
      @command = CommandLine.new([File.join(Environment.dir, 'bin/sample/custom_feed_1.sh')])
      @key = SecureRandom.hex(16)
    end

    def test_command
      @command.exec
      @renderer.entries = JSON.parse(@command.stdout)
      @storage[@key] = @renderer.to_s

      assert_kind_of(String, @storage[@key])
      @storage.unlink(@key)
      assert_nil(@storage[@key])
    end
  end
end
