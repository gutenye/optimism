require "spec_helper"
$:.unshift $spec_dir

class Optimism
  public :_fix_lambda_values, :_walk, :_split
end

def build(hash)
  o = Optimsm.new
  o._data = hash
  o
end

describe Optimism do
  # first
  describe "#==" do
    it "" do
      a = build(a: 1)
      b = build(a: 1)

      a.should == b 
    end
  end

  describe ".[]" do
    it "simple hash data" do
      Optimism({a: 1}).should == build(a: 1)
    end

    it "complex hash data" do
      Optimism({a: 1, b: {c: 1}}).should == build(a: 1, b: build(c: 1))
    end

    it "simple optimism data " do
      o = Optimism(a: 1)
      Optimism(o).should == o
    end

    it "complex optimism data" do
      data = { a: 1, b: build(c: 2), d: {e: 3}
      right = build(a: 1, b: build(c: 2), d: build(e: 3)))

      Optimism(data).should == right
    end
  end

	describe "#inspect" do
		it "works" do
      o = Optimism({a: 1, c: {d: {e: 3}}})
			expect = <<-EOF.rstrip
<#Optimism:_
  :a => 1
  :c => <#Optimism:c
    :d => <#Optimism:d
      :e => 3>>>
EOF

			o.inspect.should == expect
		end
	end

  describe "#_root" do
    it "works" do
      o = Optimism({a: {b: {c: 1}}})
      o.a.b._root.should == o
    end
  end

	describe ".get" do
		it "gets data from Hash" do
      data = {a: 1}
			Optimism.get(data).should == {a: 1}
		end
		it "gets data from Optimism" do
			o = lptimism.new
			o._data = {a: 1}
			Optimism.get(o).should == {a: 1}
		end
	end

  describe "#_fix_lambda_values" do
    it "works" do
      rc = Optimism <<-EOF
        a = lambda { 1 }.tap{|s| s.instance_variable_set(:@_optimism, true)}
        my:
          a = lambda { 2 }.tap{|s| s.instance_variable_set(:@_optimism, true)}
      EOF
      rc.should == Optimism({a: 1, my: {a: 2}})
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
      rc.should == Optimism({b: {c: {d: 1}}, a: 1})
    end
  end

  context "string-syntax" do
    it "with simple example"  do
      rc = Optimism <<-EOF
a = 1
      EOF
      rc.should == Optimism({a: 1})
    end

    it "with complex example" do
      rc = Optimism <<-EOF
a = 1
b.c:
  d = _.a
      EOF
      rc.should == Optimism({b: {c: {d: 1}}, a: 1})
    end
  end

	context "access" do
		before :all do
			@rc = Optimism({a: 1})
			@rc._data = {a: 1} 
		end

		it "#name" do
			@rc.a.should == 1
		end

		it "#name?" do
			@rc.a?.should be_true
		end

    it "#name? => false if not key" do
      @rc.dont_exist?.should be_false
    end

		it "#[] with symbol key" do
			@rc[:a].should == 1
			@rc[:b].should == nil
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
      @rc.a.should == 4
		end
	end

  context "with option only_symbol_key" do
    it "default is false" do
      o = Optimism.new
      o[:a] = 1

      o[:a].should == 1
      o["a"].should == 1

      o["a"] = 2
      o["a"].should == 2
      o[:a].should == 2
    end

    it "if true" do
      o = Optimism.new(nil, only_symbol_key: true)
      o[:a] = 1

      o[:a].should == 1
      o["a"].should_not == 1

      o["a"] = 2
      o["a"].should == 2
      o[:a].should_not == 2
    end

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
				c.count = lambda{|n| n}
				c.bar = proc{|n| n}
			end

      rc.count(1).should == 1
      rc.bar(1).should be_an_instance_of(Proc)
		end

    it "works with string-syntax" do
      rc = Optimism <<-EOF
        count = lambda{|n| n}
        bar = proc{|n| n}
      EOF

      rc.count(1).should == 1
      rc.bar(1).should be_an_instance_of(Proc)
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
			rc = Optimism(a: 1)
			rc._keys.should == [:a]
		end

		it "#_method? must comes before #method?" do
			rc = Optimism.new
			rc.i._empty?.should be_true
			rc.i.empty?.should be_false
		end
	end

  describe "#_to_hash" do
    o = Optimism({a: {b: {c: 1}}})
    o._to_hash.should == {a: Optimism({b: {c: 1}})}
  end

  describe "#_walk" do
    it "down along the path" do
      o = Optimism({a: {b: {c: 1}}})
      node = o._walk('a.b')
      node.should == Optimism({c: 1})
    end

    it "up along the path" do
      o = Optimism({a: {b: {c: 1}}})
      node = o._walk('a.b')
      node2 = node._walk('-_.a')
      node2.should == o
    end

    it "down along the path with :build" do
      o = Optimism.new
      lambda {node = o._walk('a.b')}.should raise_error(Optimism::EPath)
      node = o._walk('a.b', :build => true)
      o.should == Optimism(a: {b: Optimism.new})
    end

    it "up along the path with :build" do
      o = Optimism.new
      lambda {node = o._walk('-a.b')}.should raise_error(Optimism::EPath)
      node = o._walk('-a.b', :build => true)
      node.should == Optimism(a: {b: Optimism.new})
    end
  end

  describe "#_walk!" do
    it "down along the path" do
      o = Optimism.new
      o._walk!('a.b', :build => true)
      o._root.should == Optimism(a: {b: Optimism.new})
    end

    it "up along the path" do
      o = Optimism.new
      o._walk!('-a.b', :build => true)
      o.should == Optimism(a: {b: Optimism.new})
    end
  end

  describe "#_split" do
    it "works" do
      Optimism.new._split("foo").should == ["", :foo]
      Optimism.new._split("foo.bar.baz").should == ["foo.bar", :baz]
    end
  end

  describe "#_has_key2?" do
    it "works" do
      a = Optimism({foo: {bar: 1}})

      a._has_key2?("foo").should be_true
      a._has_key2?("foo.bar").should be_true
      a._has_key2?("bar.baz").should be_false
      a[:bar].should be_nil
    end
  end

  describe "#_fetch2" do
    before :each do
			@o = Optimism({a: {b: {c: 1}}})
    end

		it "works" do
      @o._fetch2("a.b.c").should == 1
    end

    it "return default value when path doesn't exists" do
      @o._fetch2("b.c.d",  2).should == 2
      @o[:b][:c][:d].should == 2
    end
  end

  describe "#_store2" do
    before :each do
      @o = Optimism.new
    end

    it "works with default :build is true" do
      @o._store2 'a.b', 1
      @o.should == Optimism({a: {b: 1}})
    end

    it "works with :build => false" do
      lambda {@o._store2('a.b', 1, :build => false)}.should raise_error(Optimism::EPath)
    end
  end

  describe "#_repalce" do
    it "works" do
      a = Optimism({foo: {bar: 1}})
      b = Optimism.new
      b._replace a.foo
      b.should == Optimism(bar: 1)
      b._root.should == a
    end
  end

  describe "marshal" do
    it "works" do
      rc = Optimism({a: 1, b: {c: 2}})
      content = Marshal.dump(rc)
      ret = Marshal.load(content)
      ret.should == rc
    end
  end

  describe "#_merge!" do
    it "works" do
      o = Optimism.new

      o.b._merge! a: 1
      o.should == Optimism({b: {a: 1}})

      o.b._merge! Optimism({a: 2})
      o.should == Optimism({b: {a: 2}})
    end

    #
    # o.
    #   a.b = 1
    #   a.c = "foo"
    #   b.c = "x"
    #
    # o2
    #   a.b = 2
    #   a.d = "bar"
    #
    # o << o2
    # #=>
    #  o.a.b = 2
    #  o.a.c = "foo"
    #  o.a.d = "bar"
    #  o.b.c = "x"
    it "is deep merge" do
      o = Optimism do
        a.b = 1
        a.c = "foo"
        b.c = "x"
      end

      o2 = Optimism do
        a.b = 2
        a.d = "bar"
      end

      o._merge! o2
      o.should == Optimism({a: {b: 2, c: "foo", d: "bar"}, b: {c: "x"}})
    end

    it "(string)" do  
      o = Optimism.new
      o._merge! <<-EOF
        a = 1
      EOF

      o.should == Optimism({a: 1})
    end
  end

  describe "#_merge" do
    it "works" do
      o = Optimism.new
      new = o._merge a: 1
      o.should == o
      new.should == Optimism(a: 1)
    end
  end

  describe "#_get" do
    before(:all) {
      @o = Optimism do |c|
        c.a = 1
        c.b.c = 2
      end
    }

    it "works" do
      @o._get("a").should == 1
    end

    it "support path" do
      @o._get("b.c").should == 2
    end

    it "return nil if path is not exists" do
      @o._get("c.d").should == nil
    end

    it "return nil if path is wrong" do
      @o._get("a.b").should == nil
    end
  end
end
