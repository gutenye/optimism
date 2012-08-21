module YAML
  def self.optimiam_parser
     ->{|o,data| o << self.load(data)}
  end
end
