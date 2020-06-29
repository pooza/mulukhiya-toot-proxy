module Mulukhiya
  class InvalidCommandHandler < Handler
    def disable?
      return !parser.command?
    end

    def handle_pre_toot(body, params = {})
      raise Ginseng::ValidateError, 'コマンドが指定されていません。' unless parser.command.present?
      raise Ginseng::ValidateError, "コマンド '#{parser.command}' は実行できません。"
    end
  end
end
