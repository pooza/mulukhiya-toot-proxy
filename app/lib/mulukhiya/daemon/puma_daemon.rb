module Mulukhiya
  class PumaDaemon < Ginseng::Daemon
    include Package
    include DaemonIdentityMethods

    def command
      return CommandLine.new([
        'puma',
        '--config', initializer_path
      ])
    end

    # ⚠ puma は proctitle を "puma <version> (tcp://...) [<作業ディレクトリ名>]" へ書き換える。
    # 書き換える前は "ruby .../bin/puma --config <Environment.dir>/app/initializer/puma.rb"。
    # ⚠ 同じホストの Mastodon の puma を自分と誤らないよう、タグまで含めて絞る。
    def identity_pattern
      return Regexp.union(
        launcher_pattern('puma_daemon.rb'),
        exec_pattern('puma', '--config', initializer_path),
        /puma[ :].*\[#{identity_tag}\]/,
      )
    end

    def self.disable?
      return false
    end

    def self.restart
      CommandLine.new([File.join(Environment.dir, 'bin/puma_daemon.rb'), 'restart'])
        .exec(timeout: config['/daemon/restart/timeout/seconds'])
    end

    private

    def initializer_path
      return File.join(Environment.dir, 'app/initializer/puma.rb')
    end
  end
end
