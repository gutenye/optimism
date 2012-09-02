class Optimism
  module Parser
    class YAML < Base
      def self.parse(optimism, content, opts={}, &blk)
        optimism << ::YAML.load(content)
      end
    end
  end
end

Optimism.add_extension ".yml", Optimism::Parser::YAML
