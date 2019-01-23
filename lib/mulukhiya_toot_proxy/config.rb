module MulukhiyaTootProxy
  class Config < Ginseng::Config
    include Package

    def self.deep_merge(src, target)
      raise ArgumentError 'Not Hash' unless target.is_a?(Hash)
      dest = (src.clone || {}).with_indifferent_access
      target.each do |k, v|
        dest[k] = v.is_a?(Hash) ? deep_merge(dest[k], v) : v
      end
      return dest.compact
    end
  end
end
