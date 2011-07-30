class Optimism
  #
  # make some hash methods works for <#Optimism>
  #
  module HashMethodFix
    
    # deep merge new data IN PLACE
    #
    # @params [Hash,Optimism] obj
    # @return [self]
    def _merge!(other)
      other = Optimism.convert(other)
      other._each { |k, v|
        if Optimism === self[k] and Optimism === other[k] 
          self[k]._merge!(other[k])
        else
          self[k] = other[k]
        end
      }

      self
    end

    alias << _merge!

    # deep merge new data
    #
    # @params [Hash,Optimism] obj
    # @return [Optimism] new <#Optimism>
    def _merge other
      target = dup
      other = Optimism.convert(other)

      other._each { |k, v|
        if Optimism === target[k] and Optimism === other[k] 
          target[k]._merge(other[k])
        else
          target[k] = other[k]
        end
      }

      target
    end

    # support path
    #
    # @example
    #
    #   o = Optimism do
    #     _.a = 1
    #     _.b.c = 2
    #   end
    #
    #   o._get("b.c") #=> 2
    #   o._get("c.d") #=> nil. path doesn't exist.
    #   o._get("a.b") #=> nil. path is wrong
    #
    # @param [String] key
    # @return [Object] value
    def _get(key)
      value = self
      key.split(".").each { |k|
        return nil unless Optimism === value # wrong path
        value = value[k]
        return nil if value.nil? # path doesn't exist.
      }

      value
    end
  end
end
