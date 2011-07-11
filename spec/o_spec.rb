require "spec_helper"

describe O do
	describe "#inspect" do
		it "works" do
			node1 = O.new
			node2 = O.new
			node3 = O.new
			node3._child = {a: 1, b: 2} 
			node2._child = {a: node3, b: 3}
			node1._child = { a: 1, b: 2, "a" => 112, c: node2}

			right = <<-EOF.rstrip
<#O
  :a => 1
  :b => 2
  "a" => 112
  :c => <#O
    :a => <#O
      :a => 1
      :b => 2>
    :b => 3>>
EOF

			node1.inspect.should == right
		end
	end

	describe "#initialize" do
		it "works" do
			rc = O.new do |c|
				a 1
				b 2
				c.d.e do
					a 1
				end

				d do |c|
					a 2
				end

			end
			O.pd rc
		end
	end

end

=begin
describe O::O_Eval do
	describe ".eval" do
		it "works" do
			rc = O::O_Eval.eval do
				a 9
				b 2
				c.d.e do
					#O.p a
					f 1
				end
			end
			pd rc

		end
	end
end
=end
