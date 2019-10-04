module MulukhiyaTootProxy
  class CommandLineTest < Test::Unit::TestCase
    def setup
      @command = CommandLine.new
    end

    def test_args
      @command.args = []
      assert_equal(@command.args, [])
      @command.args = ['ffmpeg', File.join(Environment.dir, 'sample/poyke.mp4')]
      assert_equal(@command.args[0], 'ffmpeg')
    end

    def test_to_s
      @command.args = ['ls', 'a b', '"x"']
      assert_equal(@command.to_s, 'ls a\\ b \\"x\\"')
    end

    def test_exec
      @command.args = ['ls', '/']
      @command.exec
      assert(@command.status.zero?)
      assert(@command.stdout.present?)
      assert(@command.stderr.blank?)

      @command.args = ['ffmpeg', File.join(Environment.dir, 'sample/poyke.mp4')]
      @command.exec
      assert_equal(@command.status, 256)
      assert(@command.stdout.blank?)
      assert(@command.stderr.start_with?('ffmpeg version'))
    end
  end
end
