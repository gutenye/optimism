require "spec_helper"
$:.unshift $spec_dir


describe Optimism do
  it "test" do
  end

  describe ".convert" do
    it "works with simple hash data" do
      Optimism.convert({a: 1}).should == Optimism[a: 1]
    end

    it "works with compilex hash data" do
      Optimism.convert({a: 1, b: {c: 1}}).should == Optimism[a: 1, b: Optimism[c: 1]]
    end

    it "works with simple optimism data" do
      o = Optimism[a: 1]
      Optimism.convert(o).should == o
    end

    it "works with complex hash and optimism data" do
      data = {
        a: 1,
        b: Optimism[c: 2],
        c: {
          e: Optimism[d: 3] 
        }
      }
      right = Optimism[a: 1, b: Optimism[c: 2], c: Optimism[e: Optimism[d: 3]]]
      Optimism.convert(data).should == right
    end
  end

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

  it "get instance_variable" do
    rc = Optimism {
      @a = 1
    }
    rc._child.should == {a: 1}
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
  context "ruby-syntax" do
    it "works" do
      $itest=true
      rc = Optimism do
        @a = 1
        b.c do
          @d = 2
        end
      end
      $itest=false
      rc.should == Optimism[b: Optimism[c: Optimism[d: 2]], a: 1]
    end

  end

  context "string-syntax" do
    it "works" do
      rc = Optimism.eval <<-EOF
a = 1
b.c:
  d = 2
      EOF
      rc.should == Optimism[a: 1, b: Optimism[c: Optimism[d: 2]]]
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

    it "root is right in ruby-syntax" do
      rc = Optimism do
        @a = 1
        @b = proc { _ }
        #_.should == Optimism[a: 1]
      end

      pd rc.b
      rc.b.a.should == 1


    end

    it "root is right in String" do
      rc = Optimism.require_string <<-EOF
a = 1

xx

_.should == Optimism[a: 1]
      EOF
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
