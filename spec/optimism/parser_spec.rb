require "spec_helper"

module Optimism::Parser
  class StringBlock2RubyBlock
    public :scan
  end
  class CollectLocalVariables
    public :remove_block_string
  end
end

include Optimism::Parser

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

    @variables = %w(a b)
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
    CollectLocalVariables.new(@content).evaluate.should == %w(a b c d l)
  end
  end
end

describe Path2Lambda do
  it "with simple example" do
    content = "foo = _.name"
    expect = "foo =  lambda { _.name }\n"
    Path2Lambda.new(content).evaluate.should == expect
  end

  it "with complex example" do
    content = <<-EOF
foo = _.name
foo = ___.name
foo = true && _foo || _.bar
    EOF
    expect = <<-EOF
foo =  lambda { _.name }
foo =  lambda { ___.name }
foo = true && _foo ||  lambda { _.bar }
    EOF

    Path2Lambda.new(content).evaluate.should == expect
  end
end
