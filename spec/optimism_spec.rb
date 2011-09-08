require "spec_helper"
$:.unshift $spec_dir

=begin

quick create a <#Optimism>
  * Optimism.convert({a: {b: 2}})
  * Optimism[a: Optimism[b: 1]] # each node has no _parent and _root.

equal
  o1 == o2 # check Class, and _child. not check _parent or _root
=end

class Optimism
  public :_fix_lambda_values, :_walk
end

describe Optimism do
  # first
  describe "#==" do
    it "" do
      a = Optimism.new
      a._child = {a: 1}

      b = Optimism.new
      b._child = {a: 1}

      a.should == b 
    end
  end
	describe ".[]" do
		it "converts Hash to Optimism" do
      o = Optimism[a: Optimism[b: 1]]

      a = Optimism.new
      a._child = {b: 1}
      right = Optimism.new
      right._child = {a: a}

      o.should == right
		end

		it "converts Optimism to Optimism" do
      node = Optimism[a: 1]

      Optimism[node].should == node
		end
	end
  describe ".convert" do
    it "simple hash data" do
      Optimism.convert({a: 1}).should == Optimism[a: 1]
    end

    it "complex hash data" do
      #Optimism.convert({a: 1, b: {c: 1}}).should == Optimism[a: 1, b: Optimism[c: 1]]
      o = Optimism.convert({a: 1, b: {c: 1}})
    end

    it "simple optimism data " do
      o = Optimism[a: 1]
      Optimism.convert(o).should == o
    end

    it "complex optimism data" do
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
	describe "#inspect" do
		it "works" do
      o = Optimism.convert({a: 1, "a" => 2, c: {d: {e: 3}}})
			expect = <<-EOF.rstrip
<#Optimism:_
  :a => 1
  "a" => 2
  :c => <#Optimism:c
    :d => <#Optimism:d
      :e => 3>>>
EOF

			o.inspect.should == expect
		end
	end

  describe "#_root" do
    it "works" do
      o = Optimism.convert({a: {b: {c: 1}}})
      o.a.b._root.should == o
    end
  end


	describe ".get" do
		it "gets data from Hash" do
      data = {a: 1}
			Optimism.get(data).should == {a: 1}
		end
		it "gets data from Optimism" do
			o = Optimism.new
			o._child = {a: 1}
			Optimism.get(o).should == {a: 1}
		end
	end

  describe "#_fix_lambda_values" do
    it "" do
      rc = Optimism do |c|
        c.a = lambda { 1 }
        my do |c|
          c.a = lambda { 2 }
        end
      end
      rc.should == Optimism[a: 1, my: Optimism[a: 2]]
    end
  end

  context "ruby-syntax" do
    it "works" do
      rc = Optimism do |c|
        c.a = 1
        b.c do |c|
          c.d = _.a
        end
      end
      rc.should == Optimism[b: Optimism[c: Optimism[d: 1]], a: 1]
    end
  end

  context "string-syntax" do
    it "with simple example"  do
      rc = Optimism <<-EOF
a = 1
      EOF
      rc.should == Optimism[a: 1]
    end

    it "with complex example" do
      rc = Optimism <<-EOF
a = 1
b.c:
  d = _.a
      EOF
      rc.should == Optimism[b: Optimism[c: Optimism[d: 1]], a: 1]
    end
  end

	context "access" do
		before :all do
			@rc = Optimism[a: 1]
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

    it "return <#Optimism> if key doesn't exist" do
      @rc.i.dont.exists.should be_an_instance_of Optimism
    end
	end

	context "assignment" do
		before :each do
			@rc = Optimism.new
		end

		it "#name= value" do
			@rc.a = 1
			@rc[:a].should == 1
		end

		it "#[:key]= value" do
			@rc[:a] = 2
			@rc.a.should == 2
		end

		it '#["key"]= value' do
      @rc[:a] = 4
			@rc["a"] = 3
			@rc["a"].should == 3
      @rc.a.should == 4
		end
	end

	context "namespace" do
		it "supports basic namespace with ruby-syntax" do
			rc = Optimism do |c|
				c.a.b.c = 1
			end
			rc.should == Optimism[a: Optimism[b: Optimism[c:1]]]
		end

    it "supports basic namespace with string-syntax" do
      rc = Optimism <<-EOF
a.b.c = 1
      EOF
      rc.should == Optimism[a: Optimism[b: Optimism[c: 1]]]
    end

		it "supports basic2 namespace with ruby-syntax" do
			rc = Optimism do |c|
				a.b do |c|
          c.c = 1
        end
			end
			rc.should == Optimism[a: Optimism[b: Optimism[c:1]]]
		end

    it "supports basic2 namespace with string-syntax" do
      rc = Optimism <<-EOF
a.b:
  c = 1
      EOF
      rc.should == Optimism[a: Optimism[b: Optimism[c: 1]]]
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

				rc.should == Optimism[age: 1, my: Optimism[age: 2, friend: Optimism[age: 3]]]
			end

			it "supports complex namespace with string-syntax" do
				rc = Optimism <<-EOF
age = 1

my:
  age = 2

  friend:
    age = 3
        EOF

        rc.should == Optimism[age: 1, my: Optimism[age: 2, friend: Optimism[age: 3]]]
      end
	end

	context "variable & path" do
		it "supports basic varaible with ruby-syntax" do
			rc = Optimism do |c|
				c.age = 1
        age.should == 1
			end
		end

		it "supports basic varaible with string-syntax" do
			rc = Optimism <<-EOF
				age = 1
        age.should == 1
      EOF
		end

		it "support root path with ruby-syntax" do
      rc = Optimism do |c|
        c.age = 1
        c.myage = _.age
      end
      rc.myage.should == 1
    end

		it "support root path with string-syntax" do
      rc = Optimism <<-EOF
        age = 1
        myage = _.age
      EOF
      rc.myage.should == 1
    end


		it "support relative path with ruby-syntax" do
      rc = Optimism do |c|
        c.age = 1
        my do |c|
          c.age = __.age
        end
      end
      rc.my.age.should == 1
    end

		it "supports relative path with string-syntax" do
      rc = Optimism <<-EOF
        age = 1
        my:
          age = __.age
      EOF
      rc.my.age.should == 1
    end

    it "with complex example in ruby-synatx" do
			rc = Optimism do |c|
				c.age = 1

				my do |c|
					c.age = 2

					friend do |c|
						c.age = 3

						age.should == 3
						__.age.should == 2
						___.age.should == 1
						_.age.should == 1
					end
				end
			end
		end

    it "with complex example in string-syntax" do
      rc = Optimism <<-EOF
        age = 1

        my:
          age = 2

          friend:
            age = 3
            cur_age = age
            root_age = _.age
            rel1_age = __.age
            rel2_age = ___.age
      EOF
      rc.my.friend.cur_age.should == 3
      rc.my.friend.root_age.should == 1
      rc.my.friend.rel1_age.should == 2
      rc.my.friend.rel2_age.should == 1
    end

  end

	context "computed attribute" do
		it "works with ruby-syntax" do
			rc = Optimism do |c|
				c.count = proc{|n| n}
        c.count(1).should == 1
			end
		end

    it "works with string-syntax" do
      rc = Optimism <<-EOF
        count = proc{|n| n}
      EOF
      rc.count(1).should == 1
    end

		it "not call with #[]" do
			rc = Optimism.new do |c|
				c.count = proc{ 1 }
			end
			rc[:count].should be_an_instance_of Proc
		end
	end

  context "semantic" do
    it "works" do
      rc = Optimism.new do |c|
        c.is_started = yes
      end
      rc.is_started?.should be_true
    end
  end

	context "hash compatibility" do
		it "works" do
			rc = Optimism[a: 1]
			rc._keys.should == [:a]
		end

		it "#_method? must comes before #method?" do
			rc = Optimism.new
			rc.i._empty?.should be_true
			rc.i.empty?.should be_false
		end
	end

  describe "#_repalce" do
    it "works" do
      a = Optimism.convert({foo: {bar: 1}})
      b = Optimism.new
      b._replace a.foo
      b.should == Optimism[bar: 1]
      b._root.should == a
    end
  end

  describe "#_walk" do
    it "down along the path" do
      o = Optimism.convert({a: {b: {c: 1}}})
      node = o._walk('a.b')
      node.should == Optimism[c: 1]
    end

    it "up along the path" do
      o = Optimism.convert({a: {b: {c: 1}}})
      node = o._walk('a.b')
      node2 = node._walk('-_.a')
      node2.should == o
    end

    it "down along the path with :build" do
      o = Optimism.new
      lambda {node = o._walk('a.b')}.should raise_error(Optimism::PathError)
      node = o._walk('a.b', :build => true)
      o.should == Optimism[a: Optimism[b: Optimism.new]]
    end

    it "up along the path with :build" do
      o = Optimism.new
      lambda {node = o._walk('-a.b')}.should raise_error(Optimism::PathError)
      node = o._walk('-a.b', :build => true)
      node.should == Optimism[a: Optimism[b: Optimism.new]]
    end
  end

  describe "#_walk!" do
    it "down along the path" do
      o = Optimism.new
      o._walk!('a.b', :build => true)
      o._root.should == Optimism[a: Optimism[b: Optimism.new]]
    end

    it "up along the path" do
      o = Optimism.new
      o._walk!('-a.b', :build => true)
      o.should == Optimism[a: Optimism[b: Optimism.new]]
    end
  end

  describe "#_set2" do
    it "works" do
      o = Optimism.new
      o._set2 'a.b', 1, :build => true
      o.should == Optimism[a: Optimism[b: 1]]
    end
  end


  describe "marshal" do
    it "works" do
      rc = Optimism.convert({a: 1, b: {c: 2}})
      content = Marshal.dump(rc)
      ret = Marshal.load(content)
      ret.should == rc
    end
  end

end
