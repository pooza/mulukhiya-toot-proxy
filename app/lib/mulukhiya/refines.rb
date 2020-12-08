module Mulukhiya
  module Refines
    class ::String
      def escape_toot
        return sub(/[@#]/, '\\0 ')
      end

      alias escape_note escape_toot

      def encrypt
        return Crypt.new.encrypt(self)
      rescue Ginseng::AuthError
        return nil
      end

      def decrypt
        return Crypt.new.decrypt(self)
      rescue Ginseng::AuthError
        return nil
      end
    end

    class ::Hash
      def deep_compact
        return clone.deep_compact!
      end

      def deep_compact!
        each do |key, value|
          case value.class.to_s
          when 'Array', 'Hash'
            self[key] = value.deep_compact!
            delete(key) unless self[key].present?
          when 'NilClass'
            delete(key)
          end
        end
        compact!
        return self
      end
    end
  end
end
