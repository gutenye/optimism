require "spec_helper"

Parser = Optimism::Parser
StringBlock2RubyBlock = Parser::StringBlock2RubyBlock
CollectLocalVariables = Parser::CollectLocalVariables
Path2Lambda = Parser::Path2Lambda

public_all_methods Parser, StringBlock2RubyBlock, CollectLocalVariables, Path2Lambda

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
      ret.should == @content_indents
    end

    it "complex example" do
      parser = StringBlock2RubyBlock.new(@content1)
      ret = parser.scan(parser.content).with_object([]) { |(token,stmt), memo|
        memo << [token, stmt]
      }
      ret.should == @content1_indents
    end
  end

	describe "#evaluate" do
		it "simple example" do
      ret = StringBlock2RubyBlock.new(@content).evaluate
      ret.should == @content_evaluate
    end

		it "complex example" do
      ret = StringBlock2RubyBlock.new(@content1).evaluate
      ret.should == @content1_evaluate
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
      ret.should == content.gsub(/\t/, "  ")+"\n"
		end

		it "works with <tab> indent" do
			content = <<EOF
a:
	b 1
EOF
			expect = <<EOF
a <<-OPTIMISM_EOF0
  b 1
OPTIMISM_EOF0\n
EOF
      StringBlock2RubyBlock.new(content).evaluate.should == expect
		end

    it "works with <space> indent" do
			content = <<EOF
a:
  b 1
EOF

			expect = <<EOF
a <<-OPTIMISM_EOF0
  b 1
OPTIMISM_EOF0\n
EOF

      StringBlock2RubyBlock.new(content).evaluate.should == expect
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
      ret.should == @content_clean
    end

    it "works with \A" do
      content=<<-EOF
a.b <<-OPTIMISM_EOF0
  c = 1
OPTIMISM_EOF0
      EOF
      expect="\n"
      ret = CollectLocalVariables.new(content).remove_block_string(content)
      ret.should == expect
    end

  end

  describe "#evaluate" do
    it "" do
      ret = CollectLocalVariables.new(@content).evaluate
      ret.should == @variables
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

      ret.should == %w(a b c d Aa .j l)
    end

    it "" do
      CollectLocalVariables.new(@content).evaluate.should == [:a, :b, :c, :d, :l]
    end
  end
end

describe Path2Lambda do
  it "with simple example" do
    content = "foo = _.name"
    expect = "foo =  lambda { _.name }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)}\n"
    Path2Lambda.new(content).evaluate.should == expect
  end

  it "with complex example" do
    content = <<-EOF
foo = _.name
foo = ___.name
foo = true && _foo || _.bar
    EOF
    expect = <<-EOF
foo =  lambda { _.name }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)}
foo =  lambda { ___.name }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)}
foo = true && _foo ||  lambda { _.bar }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)}
    EOF

    Path2Lambda.new(content).evaluate.should == expect
  end
end

describe Parser do
  before :each do
    @optimism = Optimism.new
    @parser = Parser.new(@optimism)
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
  end

  describe "#call_lambda_path" do
    it do
      o = Optimism(
        a: lambda{ 1 }.tap{|s| s.instance_variable_set(:@_optimism, true)},
        my: { a: lambda{ 2 }.tap{|s| s.instance_variable_set(:@_optimism, true)} })
      r = Optimism(a: 1, my: {a: 2})

      @parser.call_lambda_path(o)
      expect(o).to eq(r)
    end
  end

  describe "#eval_string" do
    it do
      @parser.eval_string <<-EOF
a = 1
b:
  c = 2
  d = _
      EOF

    end
  end
end


describe Optimism do
  descrieb ".parser" do
  end
end

      a = Optimism.new do |c|
        c.a = 1
        c.b do |c|
          c.c = 2
        end
      end
      r = build(a: 1, b: build(c: 2))

      expect(a).to eq(r)


    it "(str)" do
      a = Optimism <<-EOF 
a = 1
      EOF
      r = build(a: 1)
    
      expect(a).to eq(r)
    end

    it "(str) complex" do
      a = Optimism <<-EOF
a = 1
b.c:
  d = _.a
      EOF
      r = build(a: 1, b: build(c: build(d: 1)))

      expect(a).to eq(r)
    end


	context "namespace" do
		it "supports basic namespace with ruby-syntax" do
			rc = Optimism do |c|
				c.a.b.c = 1
			end
			rc.should == Optimism({a: {b: {c:1}}})
		end

    it "supports basic namespace with string-syntax" do
      rc = Optimism <<-EOF
a.b.c = 1
      EOF
      rc.should == Optimism({a: {b: {c: 1}}})
    end

		it "supports basic2 namespace with ruby-syntax" do
			rc = Optimism do |c|
				a.b do |c|
          c.c = 1
        end
			end
			rc.should == Optimism({a: {b: {c:1}}})
		end

    it "supports basic2 namespace with string-syntax" do
      rc = Optimism <<-EOF
a.b:
  c = 1
      EOF
      rc.should == Optimism({a: {b: {c: 1}}})
    end

			it "supports complex namespace with ruby-syntax" do
				rc = Optimism do |c|
					c.age = 1

					my do |c|
						c.age = 2

						friend do |c|
							c.age = 3
						end
					end
				end

				rc.should == Optimism({age: 1, my: {age: 2, friend: {age: 3}}})
			end

			it "supports complex namespace with string-syntax" do
				rc = Optimism <<-EOF
age = 1

my:
  age = 2

  friend:
    age = 3
        EOF

				rc.should == Optimism({age: 1, my: {age: 2, friend: {age: 3}}})
      end
	end
