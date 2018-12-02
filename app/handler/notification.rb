module MulukhiyaTootProxy
  class NotificationHandler < SidekiqHandler
    def executable?
      return true
    end

    def param
      return 'あああああ'
    end
  end
end
