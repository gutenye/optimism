class O
  #
  # make some hash methods works for <#O>
  #
  module HashMethodFix
    
    # merge new data IN PLACE
    #
    # @params [Hash,O] obj
    # @return [self]
    def _merge! obj
      _child.merge! O.get(obj)
      self
    end

    # merge new data
    #
    # @params [Hash,O] obj
    # @return [O] new <#O>
    def _merge obj
      data = _child.merge(O.get(obj))
      O[data]
    end

  end
end
