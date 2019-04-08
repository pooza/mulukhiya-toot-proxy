module MulukhiyaTootProxy
  class ResultContainer < Array
    def summary
      return map{|v| "#{v[:handler]}:#{v.count}"}.join(', ')
    end
  end
end
