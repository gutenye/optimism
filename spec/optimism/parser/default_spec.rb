require "spec_helper"

Default = Optimism::Parser::Default
StringBlock2RubyBlock = Default::StringBlock2RubyBlock
CollectLocalVariables = Default::CollectLocalVariables
Path2Lambda = Default::Path2Lambda
public_all_methods Default, StringBlock2RubyBlock, CollectLocalVariables, Path2Lambda

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
a <<-OPTIMISM_EOF0
  b = 1
OPTIMISM_EOF0\n
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
b <<-OPTIMISM_EOF0
  c = {d: 1}
  d = 1
  e <<-OPTIMISM_EOF1
    f.h = 1
  OPTIMISM_EOF1
OPTIMISM_EOF0
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
a <<-OPTIMISM_EOF0
  b 1
OPTIMISM_EOF0\n
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
a <<-OPTIMISM_EOF0
  b 1
OPTIMISM_EOF0\n
EOF

      ret = StringBlock2RubyBlock.new(content).evaluate

      expect(ret).to eq(r)
    end
	end
end

describe CollectLocalVariables do
  before(:all) {
    @content=<<-EOF
a = 1
my.name <<-OPTIMISM_EOF0
  c = 1
  e.f <<-OPTIMISM_EOF1
    d = 2
  OPTIMISM_EOF1
OPTIMISM_EOF0
b = 2
    EOF
  @content_clean=<<-EOF
a = 1
b = 2
    EOF

    @variables = [:a, :b]
  }

  describe "#remove_block_strint" do
    it "" do
      ret = CollectLocalVariables.new(@content).remove_block_string(@content)
      expect(ret).to eq(@content_clean)
    end

    it "works with \A" do
      content=<<-EOF
a.b <<-OPTIMISM_EOF0
  c = 1
OPTIMISM_EOF0
      EOF
      r="\n"
      ret = CollectLocalVariables.new(content).remove_block_string(content)

      expect(ret).to eq(r)
    end

  end

  describe "#evaluate" do
    it "" do
      ret = CollectLocalVariables.new(@content).evaluate
      expect(ret).to eq(@variables)
    end
  end

  context "complex example" do
    before :all do
      @content = <<-EOF
a=1
b = 1
c=1; d=2
e=~//; f==1; g===2;

Aa = 1

h.j = 1

k[0] = 1

if (l=1)
EOF
    end

    it "scan with pat" do
      ret = @content.scan(CollectLocalVariables::LOCAL_VARIABLE_PAT).each.with_object([]) { |match, memo|
        memo << match[1]
      }

      expect(ret).to eq(%w[a b c d Aa .j l])
    end

    it "" do
      ret = CollectLocalVariables.new(@content).evaluate
      expect(ret).to eq([:a, :b, :c, :d, :l])
    end
  end
end

describe Path2Lambda do
  it "with simple example" do
    content = "foo = _.name"
    r = "foo =  lambda { _.name }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)}\n"

    ret = Path2Lambda.new(content).evaluate
    expect(ret).to eq(r)
  end

  it "with complex example" do
    content = <<-EOF
foo = _.name
foo = ___.name
foo = true && _foo || _.bar
    EOF
    r = <<-EOF
foo =  lambda { _.name }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)}
foo =  lambda { ___.name }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)}
foo = true && _foo ||  lambda { _.bar }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)}
    EOF

    ret = Path2Lambda.new(content).evaluate
    expect(ret).to eq(r)
  end
end

describe Default do
  before :each do
    @optimism = Optimism.new
    @parser = Default.new(@optimism)
  end

  describe "#eval_block" do
    it do
      @parser.eval_block do |o|
        o[:a] = 1
      end

      expect(@optimism[:a]).to eq(1)
    end
  end

  describe "#collect_variables" do
    it do
      @parser.collect_variables("a = 1")
      expect(@optimism[:a]).to eq(1)
    end

    it "raise EParse" do
      expect{@parser.collect_variables("guten 123 123")}.to raise_error(Optimism::EParse)
    end
  end

  describe "#call_lambda_path" do
    it do
      o = Optimism(
        a: lambda{ 1 }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)},
        my: { a: lambda{ 2 }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)} })
      r = Optimism(a: 1, my: {a: 2})

      @parser.call_lambda_path(o)
      expect(o).to eq(r)
    end
  end

  xdescribe "#eval_string" do
    it do
      @parser.eval_string <<-EOF
a = 1
b:
  c = 2
  d = _
      EOF

    end
  end

  context "(complete)" do
    it "{|c| block}" do
      a = Optimism.new do |c|
        c.a = 1
        c.b.c = 2
        c.c.d do |c|
          c.e = 3
        end
      end
      r = Optimism({a: 1, b: {c: 2}, c: {d: {e: 3}}})

      expect(a).to eq(r)
    end

    it "{ block }" do
      a = Optimism.new do
        _.a = 1
        _.b do
          _.c = 2
        end
      end
      r = Optimism({a: 1, b: {c: 2}})

      expect(a).to eq(r)
    end

    xit "(str)" do
      a = Optimism <<-EOF 
a = 1
b.c = 2
c.d:
  e = 2
  e1 = _.e
  e2 = _r.a
  e3 = __.a

  f:
    g = 3

      EOF
      r = Optimism({a: 1, b: {c: 2}, c: {d: {e: 2, e1: 2, e2: 1, e3: 1, f: {g: 3}}}})
    
      expect(a).to eq(r)
    end
  end
end
