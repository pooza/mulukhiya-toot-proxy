module Mulukhiya
  class CommandLine < Ginseng::CommandLine
    include Package

    def response
      parts = stdout.split("\n\n")
      return {body: stdout, type: APIController.default_type} if parts.count < 2
      headers = WEBrick::HTTPUtils.parse_header(parts.shift)
      return {
        body: parts.join("\n\n"),
        type: headers['content-type']&.first || APIController.default_type,
      }
    end

    def self.create(params)
      params = params.deep_symbolize_keys
      command = CommandLine.new(params[:command])
      command.dir = params[:dir] || Environment.dir
      command.env = params[:env] if params[:env]
      return command
    rescue => e
      e.log
      return nil
    end
  end
end
