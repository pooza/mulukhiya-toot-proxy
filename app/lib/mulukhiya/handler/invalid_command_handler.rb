module Mulukhiya
  class InvalidCommandHandler < Handler
    def disable?
      return parser.invalid_command?
    end

    def handle_pre_toot(body, params = {})
      raise ValidateError, 'コマンドが指定されていません。' unless parser.command.present?
      raise ValidateError, "コマンド '#{parser.command}' は実行できません。"
    end
  end
end
