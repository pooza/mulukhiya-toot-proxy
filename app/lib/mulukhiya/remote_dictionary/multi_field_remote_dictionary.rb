module Mulukhiya
  class MultiFieldRemoteDictionary < RemoteDictionary
    def parse
      result = {}
      fetch.each do |entry|
        fields.each do |field|
          next unless entry[field]
          result[create_key(v.first)] = create_entry(entry[field])
        end
      rescue => e
        @logger.error(error: e, dic: uri.to_s, entry: entry)
      end
      return result
    end

    def fields
      @fields ||= @params['/fields'] || ['word']
      return @fields
    end
  end
end
