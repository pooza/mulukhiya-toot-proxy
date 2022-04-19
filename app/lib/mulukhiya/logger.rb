module Mulukhiya
  class Logger < Ginseng::Logger
    include Package

    def create_message(src)
      src = mask(src) if src.is_a?(Hash)
      return super
    end

    def mask(arg)
      if arg.is_a?(Hash)
        arg.deep_stringify_keys!
        arg.reject {|_, v| v.to_s.empty?}.each do |k, v|
          if config['/logger/mask_fields'].member?(k)
            arg.delete(k)
          else
            arg[k] = mask(v)
          end
        end
      end
      return arg
    end
  end
end
