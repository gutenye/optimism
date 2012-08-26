require "spec_helper"
require "yaml"

YAMLParser = Optimism::Parser::YAML

describe YAMLParser do
  it do
    o = Optimism.new
    r = Optimism({foo: [1, 2]})
    YAMLParser.parse(o, "foo: [1, 2]")

    expect(o).to eq(r)
  end
end
