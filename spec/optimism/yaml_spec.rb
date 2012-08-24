require "spec_helper"
require "yaml"

describe YAML do
  describe ".optimism_parser" do
    it do
      o = Optimism.new
      expect(YAML.optimism_parser.call(o, "{a: 1}")).to eq(Optimism({a: 1}))
    end
  end
end
