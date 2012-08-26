class Optimism
  module Parser
    @@parsers = {}

    # list of all parsers.
    # {name: method}
    def self.parsers
      @@parsers
    end
  end
end

require "optimism/parser/base"
