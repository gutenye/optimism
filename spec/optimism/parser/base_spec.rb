require "spec_helper"

Base = Optimism::Parser::Base

class Optimism::MyFoo < Base; end

describe Base do
  it do
    expect(Optimism::Parser.parsers[:myfoo]).to eq(Optimism::MyFoo) 
  end
end
