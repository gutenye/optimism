require "spec_helper"

describe Optimism do
	describe ".get" do
		it "gets from Hash" do
			Optimism.get(a: 1).should == {a: 1}
		end
		it "gets from Optimism" do
			o = Optimism.new
			o._child = {a:1}
			Optimism.get(o).should == {a: 1}
		end
	end
	describe ".[]" do
		it "converts Hash to Optimism" do
			Optimism[a:1].should be_an_instance_of Optimism
		end
	end
	describe ".require" do
		it "raise LoadError when file doesn't exist" do
			lambda{Optimism.require "file/doesnt/exists"}.should raise_error(Optimism::LoadError)
		end

		it "loads an absolute path" do
			Optimism.require(File.join($spec_data_dir, 'rc.rb'))._child == {a: 1}
		end

		it "loads a relative path" do
			$: << $spec_data_dir
			Optimism.require('rc')._child == {a: 1}
			Optimism.require('rc.rb')._child == {a: 1}
		end

		it "loads a home path" do
			ENV["HOME"] = $spec_data_dir
			Optimism.require('rc.rb')._child == {a: 1}
		end

	end

	context "access" do
		before :all do
			@rc = Optimism.new
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
			@rc = Optimism.new
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

	context "initalize with default value" do
		it "default value is nil" do
			rc = Optimism.new
			rc[:foo].should == nil
		end

		it "init with default value 1" do
			rc = Optimism.new 1
			rc[:foo].should == 1
		end
	end

	it "return <#Optimism> if key doesn't exist" do
		rc = Optimism.new
		rc.i.dont.exists.should be_an_instance_of Optimism
	end

	context "basic syntax" do
		it "works" do
			rc = Optimism.new do 
				a 1
			end

			rc._child.should == {a: 1}
		end

		it "has block-style syntax" do
			rc = Optimism.new do |c|
				c.a = 1
			end
			rc._child.should == {a: 1}
		end

		it "more complex one" do
			rc = Optimism.new do
				self.a = 1
				self[:b] = 2
			end
			rc._child.should == {a: 1, b: 2}
		end

	end
	context "namespace" do

		it "supports basic namespace" do
			rc = Optimism.new do
				a.b.c 1
			end
			rc._child.should == {a: Optimism[b: Optimism[c:1]]}
		end

		it "support block namespace" do
			rc = Optimism.new do
				b.c do
					d 1
				end
			end
			rc._child.should == {b: Optimism[c: Optimism[d:1]]}
		end

		it "supports redefine in basic namspace" do
			rc = Optimism.new do
				a.b.c 1
				a.b.c 2
			end
			rc._child.should == {a: Optimism[b: Optimism[c:2]]}
		end

		it "supports redefine in lock namespace" do
			rc = Optimism.new do
				a.b.c 3
				a.b do 
					c 4
				end
			end
			rc._child.should == {a: Optimism[b: Optimism[c:4]]}
		end

			it "complex namespace" do
				rc = Optimism.new do
					age 1

					my do
						age 2

						friend do
							age 3
						end
					end
				end

				rc.should == Optimism[age: 1, my: Optimism[age: 2, friend: Optimism[age: 3]]]
			end
	end

	context "variable & path" do
		it "support basic varaible" do
			rc = Optimism.new do
				age 1
				myage age+1
			end

			rc.myage.should == 2
		end

		it "support path" do
			rc = Optimism.new do
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
			rc = Optimism.new do
				count proc{base+=1}
			end
			rc.count.should == 2
			rc.count.should == 3
		end

		it "support argument" do
			rc = Optimism.new do
				count proc{|n|n+1}
			end
			rc.count(1).should == 2
		end

		it "#[]" do
			rc = Optimism.new do
				count proc{1}
			end
			rc[:count].should be_an_instance_of Proc
		end

		it "#name=" do
			rc = Optimism.new do
				count proc{1}
			end
			rc.name = 1
			rc.name.should == 1
		end
	end

	it "is semantics" do
		rc = Optimism.new do
			is_started no
		end

		rc.is_started?.should be_false
	end

	context "hash compatibility" do
		it "works" do
			rc = Optimism.new do
				a 1
			end

			rc._keys.should == [:a]
		end

		it "_method? must comes before method?" do
			rc = Optimism.new
			rc.i._empty?.should be_true
			rc.i.empty?.should be_false
		end

	end

	context "temporarily change" do
		it "works" do
			rc = Optimism.new do
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
			node1 = Optimism.new
			node2 = Optimism.new
			node3 = Optimism.new
			node3._child = {a: 1, b: 2} 
			node2._child = {a: node3, b: 3}
			node1._child = { a: 1, b: 2, "a" => 112, c: node2}

			right = <<-EOF.rstrip
<#Optimism
  :a => 1
  :b => 2
  "a" => 112
  :c => <#Optimism
    :a => <#Optimism
      :a => 1
      :b => 2>
    :b => 3>>
EOF

			node1.inspect.should == right
		end
	end

end
