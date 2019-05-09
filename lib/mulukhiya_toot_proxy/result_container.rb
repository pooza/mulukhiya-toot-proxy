module MulukhiyaTootProxy
  class ResultContainer < Array
    def summary
      return map{|v| "#{v[:handler]}:#{v.count}"}.join(', ')
    end

    def push(value)
      super(value) if value
    end
  end
end
