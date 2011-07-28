class Optimism
  #
  # make some hash methods works for <#Optimism>
  #
  module HashMethodFix
    
    # merge new data IN PLACE
    #
    # @params [Hash,Optimism] obj
    # @return [self]
    def _merge! obj
      _child.merge! Optimism.get(obj)
      self
    end

    # merge new data
    #
    # @params [Hash,Optimism] obj
    # @return [Optimism] new <#Optimism>
    def _merge obj
      data = _child.merge(Optimism.get(obj))
      Optimism[data]
    end

  end
end
