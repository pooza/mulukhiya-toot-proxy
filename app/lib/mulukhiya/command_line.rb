module Mulukhiya
  class CommandLine < Ginseng::CommandLine
    include Package

    def self.create(params)
      params = params.deep_symbolize_keys
      command = CommandLine.new(params[:command])
      command.args.push(params[:path])
      command.dir = params[:dir] || Environment.dir
      command.env = params[:env] if params[:env]
      return command
    rescue => e
      logger.error(error: e)
      return nil
    end
  end
end
