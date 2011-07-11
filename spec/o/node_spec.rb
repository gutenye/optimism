require "spec_helper"


describe O::Node do
	describe "#inspect" do
		it "works" do
			node1 = O::Node.new
			node2 = O::Node.new
			node3 = O::Node.new
			node3._child = {a: 1, b: 2} 
			node2._child = {a: node3, b: 3}
			node1._child = { a: 1, b: 2, "a" => 112, c: node2}


			right = <<-EOF.rstrip
<#Node
  :a => 1
  :b => 2
  "a" => 112
  :c => <#Node
    :a => <#Node
      :a => 1
      :b => 2>
    :b => 3>>
EOF

			node1.inspect.should == right
		end
	end


end
