module Mulukhiya
  class MultiFieldRemoteDictionary < RemoteDictionary
    def parse
      result = {}
      fetch.each do |entry|
        fields.select {|v| entry[v]}.each do |field|
          result[create_key(entry[field])] ||= create_entry(entry[field])
        end
      rescue => e
        e.log(dic: uri.to_s, entry: entry)
      end
      return result
    end

    def fields
      @fields ||= @params['/fields'] || ['word']
      return @fields
    end
  end
end
