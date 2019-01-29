require 'daemon_spawn'

module MulukhiyaTootProxy
  class Daemon < DaemonSpawn::Base
    def initialize(opts = {})
      opts[:application] ||= classname
      opts[:working_dir] ||= Environment.dir
      opts[:log_file] ||= File.join(opts[:working_dir], 'log', "#{opts[:application]}.log")
      opts[:sync_log] ||= true
      opts[:singleton] ||= true
      super(opts)
    end
  end
end
