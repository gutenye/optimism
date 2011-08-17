require "spec_helper"

class Optimism::Parser
	public :compile, :scan
end

describe Optimism::Parser do
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

			parser = Optimism::Parser.new content
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
		parser = Optimism::Parser.new content
		parser.scan do |token, statement|
			#pd token, statement
		end

		parser = Optimism::Parser.new content
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
			parser = Optimism::Parser.new content
			parser.scan do |token, statement|
				#pd token, statement
			end

			parser = Optimism::Parser.new content
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
			parser = Optimism::Parser.new content
			parser.scan do |token, statement|
				#pd token, statement
			end

			parser = Optimism::Parser.new content
			#puts parser.compile
		end

	end

	describe ".compile" do
		it "works" do
			content = <<EOF
a:
	b 1
EOF
			right = <<EOF
a do
	b 1
end\n
EOF

			Optimism::Parser.compile(content).should == right

		end
	end
end
