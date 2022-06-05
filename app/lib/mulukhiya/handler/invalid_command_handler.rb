module Mulukhiya
  class InvalidCommandHandler < Handler
    def disable?
      return true unless parser.command?
      return false
    end

    def toggleable?
      return false
    end

    def handle_pre_toot(payload, params = {})
      raise Ginseng::ValidateError, 'コマンドが指定されていません。' if parser.command.empty?
      raise Ginseng::ValidateError, "コマンド '#{parser.command}' は実行できません。"
    end
  end
end
