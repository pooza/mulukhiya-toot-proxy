module Mulukhiya
  module Refines
    class ::String
      def encrypt
        return Crypt.new.encrypt(self)
      end

      def decrypt
        return Crypt.new.decrypt(self)
      end

      def blockquote(c = '>')
        return self.dup.each_line.map {|l| "#{c} #{l.chomp}"}.join("\n")
      end
    end

    class ::Hash
      def to_yaml
        return YAML.dump(deep_stringify_keys)
      end
    end

    class ::Array
      def to_yaml
        return YAML.dump(deep_stringify_keys)
      end
    end

    class ::Set
      def to_yaml
        return YAML.dump(to_a.deep_stringify_keys)
      end
    end

    class ::StandardError
      def log(values = {})
        Logger.new.error({error: self}.merge(values))
        warn(to_h.to_yaml) if Environment.test? && Environment.development?
      end

      def alert(values = {})
        log(values)
        Event.new(:alert).dispatch(self)
      end

      def source_class
        return self.class
      end
    end
  end
end
