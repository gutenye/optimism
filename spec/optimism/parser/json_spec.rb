require "spec_helper"
require "json"

JSONParser = Optimism::Parser::JSON

describe JSONParser do
  it do
    o = Optimism.new
    r = Optimism({foo: [1, 2]})
    JSONParser.parse(o, %~{"foo": [1, 2]}~)

    expect(o).to eq(r)
  end
end
