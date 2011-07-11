require "spec_helper"

describe O do
	describe ".get" do
		it "gets from Hash" do
			O.get(a: 1).should == {a: 1}
		end
		it "gets from O" do
			o = O.new
			o._child = {a:1}
			O.get(o).should == {a: 1}
		end
	end
	describe ".[]" do
		it "converts Hash to O" do
			O[a:1].should be_an_instance_of O
		end
	end
	describe ".require" do
		it "raise LoadError when file doesn't exist" do
			lambda{O.require "file/doesnt/exists"}.should raise_error(O::LoadError)
		end

		it "loads an absolute path" do
			O.require(File.join($spec_data_dir, 'rc.rb'))._child == {a: 1}
		end

		it "loads a relative path" do
			$: << $spec_data_dir
			O.require('rc')._child == {a: 1}
			O.require('rc.rb')._child == {a: 1}
		end

		it "loads a home path" do
			ENV["HOME"] = $spec_data_dir
			O.require('rc.rb')._child == {a: 1}
		end

	end

	context "access" do
		before :all do
			@rc = O.new
			@rc._child = {a: 1} 
		end

		it "#name" do
			@rc.a.should == 1
		end

		it "#name?" do
			@rc.a?.should be_true
		end

		it "#[]" do
			@rc[:a].should == 1
		end

	end
	context "assignment" do
		before :each do
			@rc = O.new
		end

		it "#name value" do
			@rc.a 1
			@rc[:a].should == 1
		end

		it "#name= value" do
			@rc.a = 1
			@rc[:a].should == 1
		end

		it "#[:key]= value" do
			@rc[:a] = 1
			@rc[:a].should == 1
		end

		it '#["key"]= value' do
			@rc["a"] = 1
			@rc[:a].should == 1
		end
	end
	it "return <#O> if key doesn't exist" do
		rc = O.new
		rc.i.dont.exists.should be_an_instance_of O
	end

	context "basic syntax" do
		it "works" do
			rc = O.new do 
				a 1
			end

			rc._child.should == {a: 1}
		end

		it "more complex one" do
			rc = O.new do
				self.a = 1
				self[:b] = 2
			end
			rc._child.should == {a: 1, b: 2}
		end

	end
	context "namespace" do

		it "supports basic namespace" do
			rc = O.new do
				a.b.c 1
			end
			rc._child.should == {a: O[b: O[c:1]]}
		end

		it "support block namespace" do
			rc = O.new do
				b.c do
					d 1
				end
			end
			rc._child.should == {b: O[c: O[d:1]]}
		end

		it "supports redefine in basic namspace" do
			rc = O.new do
				a.b.c 1
				a.b.c 2
			end
			rc._child.should == {a: O[b: O[c:2]]}
		end

		it "supports redefine in lock namespace" do
			rc = O.new do
				a.b.c 3
				a.b do 
					c 4
				end
			end
			rc._child.should == {a: O[b: O[c:4]]}
		end

			it "complex namespace" do
				rc = O.new do
					age 1

					my do
						age 2

						friend do
							age 3
						end
					end
				end

				rc.should == O[age: 1, my: O[age: 2, friend: O[age: 3]]]
			end
	end

	context "variable & path" do
		it "support basic varaible" do
			rc = O.new do
				age 1
				myage age+1
			end

			rc.myage.should == 2
		end

		it "support path" do
			rc = O.new do
				age 1
				_.age.should == 1

				my do
					age 2

					friend do
						age 3

						age.should == 3
						__.age.should == 2
						___.age.should == 1
						_.age.should == 1
					end
				end
			end
		end
	end

	context "computed attribute" do
		it "works" do
			base = 1
			rc = O.new do
				count proc{base+=1}
			end
			rc.count.should == 2
			rc.count.should == 3
		end

		it "support argument" do
			rc = O.new do
				count proc{|n|n+1}
			end
			rc.count(1).should == 2
		end

		it "#[]" do
			rc = O.new do
				count proc{1}
			end
			rc[:count].should be_an_instance_of Proc
		end

		it "#name=" do
			rc = O.new do
				count proc{1}
			end
			rc.name = 1
			rc.name.should == 1
		end
	end

	it "is semantics" do
		rc = O.new do
			is_started no
		end

		rc.is_started?.should be_false
	end

	context "hash compatibility" do
		it "works" do
			rc = O.new do
				a 1
			end

			rc._keys.should == [:a]
		end
	end

	context "temporarily change" do
		it "works" do
			rc = O.new do
				a 1
			end

			rc._temp do
				rc.a 2
				rc.a.should == 2
			end
			rc.a.should == 1
		end
	end

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
end
