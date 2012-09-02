class Optimism::Parser::JSON < Optimism::Parser::Base
  def self.parse(optimism, content, opts={}, &blk)
    optimism << ::JSON.parse(content)
  end
end

Optimism.add_extension ".json", Optimism::Parser::JSON
