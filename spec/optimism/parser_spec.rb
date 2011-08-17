require "spec_helper"

Parser = Optimism::Parser

class Optimism::Parser
	public :compile, :scan
end

describe Parser do
	describe "#token" do
		it "tests" do
			content = <<EOF
a 1
b:
	c {d: 1}
	d 1
	e:
		f 1
EOF
			content = <<EOF
a 1
b:
	c {d: 1}
	d 1
	e:
		f 1
g 1
EOF

			parser = Parser.new content
			parser.scan do |token, statement|
				#pd token, statement
			end
		end
	end

	describe "#compile" do
		it "tests" do
			content = <<EOF
a:
	b 1
EOF

			content1 = <<EOF
a 1
b:
	c {d: 1}
	d 1
	e:
		f 1
g 1
EOF
		parser = Parser.new content
		parser.scan do |token, statement|
			#pd token, statement
		end

		parser = Parser.new content
		#puts parser.compile
		end


		it "has no effects to normal ruby code" do
			content = <<EOF
a 1
b do
	c {d: 1}
	d 1
	e do
		f 1
	end
end
EOF
			parser = Parser.new content
			parser.scan do |token, statement|
				#pd token, statement
			end

			parser = Parser.new content
			#puts parser.compile
		end

		it "has both yaml-style and ruby-style" do
			content = <<EOF
a 1
b: 
	c {d: 1}
	d 1
	e do
		f 1
	end
EOF
			parser = Parser.new content
			parser.scan do |token, statement|
				#pd token, statement
			end

			parser = Parser.new content
			#puts parser.compile
		end

	end

  describe ".remove_block_string" do    
    it "works" do
      content=<<-EOF
a = 1
b:
  c = 1
d: 
  e:
   f = 1
  g = 2

f = 2

g:
 h = 4
      EOF
    expect=<<-EOF
a = 1
f = 2

      EOF
      Parser.remove_block_string(content).should == expect
    end
  end

	describe ".compile" do
		it "works with <tab> indent" do
			content = <<EOF
a:
	b 1
EOF


			right = <<EOF
a._eval <<-EOF
  b 1
EOF\n
EOF

			Parser.compile(content).should == right
		end

    it "works with <space> indent" do
			content = <<EOF
a:
  b 1
EOF

			right = <<EOF
a._eval <<-EOF
  b 1
EOF\n
EOF

      Parser.compile(content).should == right
    end
	end

  describe ".collect_local_variables" do
    before :all do
      @code = <<-EOF
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

    it "parse local variables" do
      rst = @code.scan(Parser::LOCAL_VARIABLE_PAT).each.with_object([]) { |match, memo|
        memo << match[1]
      }

      rst.should == %w(a b c d Aa .j l)
    end

    it ".collect_local_variables" do
      rst = Parser.collect_local_variables(@code)
      rst.should == %w(a b c d l)
    end
  end
end
