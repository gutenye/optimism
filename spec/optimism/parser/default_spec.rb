require "spec_helper"


foo = <<EOF
_.a = 1
b.d do
  _.c = 1
  _.d = _.c
  _.e = __.a
end
EOF

f = Optimism.new
f.instance_eval(foo)
p :f, f


Default = Optimism::Parser::Default
StringBlock2RubyBlock = Default::StringBlock2RubyBlock
LocalVariable2Method  = Default::LocalVariable2Method
public_all_methods Default, StringBlock2RubyBlock

describe StringBlock2RubyBlock do
    # simple
  before(:all) {
    @content = <<-EOF
a:
  b = 1
    EOF

    @content_indents = [
      [ :undent, nil ],
      [ :block_start, "a:"],
      [ :indent, nil ],
      [ :statement, "b = 1" ],
      [ :dedent, nil ],
      [ :statement, "" ],
    ]

    @content_evaluate = <<-EOF
a do
  b = 1
end\n
  EOF
  }
    # complex
  before(:all) {
    @content1 = <<-EOF
a = 1

b:
  c = {d: 1}
  d = 1
  e:
    f.h = 1
g = 1
    EOF

    @content1_indents = [
      [ :undent, nil ],
      [ :statement, "a = 1"],
      [ :undent, nil ], 
      [ :block_start, "b:"],
      [ :indent, nil ],
      [ :statement, "c = {d: 1}" ],
      [ :undent, nil ],
      [ :statement, "d = 1" ],
      [ :undent, nil ],
      [ :block_start, "e:" ],
      [ :indent, nil ],
      [ :statement, "f.h = 1" ],
      [ :dedent, nil ],
      [ :dedent, nil ],
      [ :statement, "g = 1" ],
      [ :undent, nil ],
      [ :statement, "" ],
    ]

  @content1_evaluate = <<-EOF
a = 1
b do
  c = {d: 1}
  d = 1
  e do
    f.h = 1
  end
end
g = 1\n
  EOF
  }

	describe "#scan" do
		it "simple example" do
			parser = StringBlock2RubyBlock.new(@content)
			ret = parser.scan(parser.content).with_object([]) { |(token,stmt), memo|
				memo <<  [token, stmt]
      }

      expect(ret).to eq(@content_indents)
    end

    it "complex example" do
      parser = StringBlock2RubyBlock.new(@content1)
      ret = parser.scan(parser.content).with_object([]) { |(token,stmt), memo|
        memo << [token, stmt]
      }

      expect(ret).to eq(@content1_indents)
    end
  end

	describe "#evaluate" do
		it "simple example" do
      ret = StringBlock2RubyBlock.new(@content).evaluate

      expect(ret).to eq(@content_evaluate)
    end

		it "complex example" do
      ret = StringBlock2RubyBlock.new(@content1).evaluate

      expect(ret).to eq(@content1_evaluate)
    end

		it "has no effect to ruby-syntax" do
			content = <<-EOF
a = 1
b do
  c = {d: 1}
  d = 1
  e do
    f.h = 1
  end
end
    EOF
			ret = StringBlock2RubyBlock.new(content).evaluate

      expect(ret).to eq(content.gsub(/\t/, "  ")+"\n")
		end

		it "works with <tab> indent" do
			content = <<EOF
a:
	b 1
EOF
			r = <<EOF
a do
  b 1
end\n
EOF
      ret = StringBlock2RubyBlock.new(content).evaluate

      expect(ret).to eq(r)
		end

    it "works with <space> indent" do
			content = <<EOF
a:
  b 1
EOF

			r = <<EOF
a do
  b 1
end\n
EOF

      ret = StringBlock2RubyBlock.new(content).evaluate

      expect(ret).to eq(r)
    end
	end
end

describe LocalVariable2Method do 
  it do
    content = <<-EOF
a = 1
a.b = 2
_.a = 3

b do
  c = 2
  d = _.c
  _.c = 3

  d do
    e = 4
  end
end

puts 1
'a' == 'a'
'a' =~ /./
    EOF
    r = <<-EOF
_.a = 1
_.a.b = 2
_.a = 3

b do
  _.c = 2
  _.d = _.c
  _.c = 3

  d do
    _.e = 4
  end
end

puts 1
'a' == 'a'
'a' =~ /./
    EOF

    ret = LocalVariable2Method.new(content).evaluate
    expect(ret).to eq(r)
  end
end

describe Default do
  before :each do
    @parser = Default.new(Optimism.new)
  end

  describe "#eval_block" do
    it do
      ret = @parser.eval_block do |o|
        o[:a] = 1
      end
      r = Optimism({a: 1})

      expect(ret).to eq(r)
    end

    it "(complex)" do
      a = @parser.eval_block do 
        _.a = 1
        _.b.c do
          _.d = 2
          _.e = _.d
          _.f = ___.a
          _.g = _r.a
        end
      end
      r = Optimism({a: 1, b: {c: {d: 2, e: 2, f: 1, g: 1}}})

      expect(a).to eq(r)
    end
  end

  describe "#eval_string" do
    it do
      ret = @parser.eval_string <<-EOF
a = 1
b:
  c = 2
  d = _.c
      EOF
      r = Optimism({a: 1, b: {c: 2, d: 2}})

      expect(ret).to eq(r)
    end

    it "(complex)" do
      ret = @parser.eval_string <<-EOF
a = 1
b.c = 2
c.d:
  e = 2
  e1 = _.e
  e2 = ___.a
  e3 = _r.a

  f:
    g = 3
      EOF
      r = Optimism({a: 1, b: {c: 2}, c: {d: {e: 2, e1: 2, e2: 1, e3: 1, f: {g: 3}}}})
    
      expect(ret).to eq(r)
    end
  end
end
