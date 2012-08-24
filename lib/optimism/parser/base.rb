class Optimism
  module Parser
    # Base class of all parsers
    #
    # @example
    #
    #   class MyParser < Optimism::Parser::Base
    #     def self.parse(optimism, content, &blk)
    #       optimism["foo"] = content
    #     end
    #   end
    #
    #   o = Optimism.new("hello", parser: "myparser")
    #   p o["foo"]      -> "hello"
    #
    class Base
      def self.inherited(child)
        Parser.parsers[child.name.split("::").last.downcase.to_sym] = child
      end

      # implement
      def self.parse(optimism, content, &blk)
        raise NotImplementedError
      end
    end
  end
end
