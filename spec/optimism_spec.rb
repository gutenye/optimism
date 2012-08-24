require "spec_helper"

public_all_methods Optimism

describe Optimism do
  # helper method to build <#Optimism>.
  def build(hash, o={})
    o = Optimism.new(nil, o)
    o._data = hash
    o
  end

  before :all do
    @optimism = Optimism.new
  end

  describe "#==" do
    it do
      a = build(a: 1, b: build(c: 2))
      b = build(a: 1, b: build(c: 2))
      c = build(a: 1, b: build(c: 3))

      expect(a).to eq(b)
      expect(a).not_to eq(c)
    end
  end

	describe "#inspect" do
		it do
      a = build({a: 1, c: build({d: build({e: 3}, name: "d")}, name: "c")})
			r = <<-EOF.rstrip
<#Optimism:
  :a => 1
  :c => <#Optimism:c
    :d => <#Optimism:d
      :e => 3>>>
    EOF

			expect(a.inspect).to eq(r)
		end
	end

  describe "#_convert_hash" do
    before :all do
      @o = Optimism.new
    end

    it do
      a = {a: 1, b: {c: {d: 2}}}
      ret = @optimism._convert_hash(a)

      expect(ret[:b]._name).to eq("b")
      expect(ret[:b].c._parent._name).to eq("b")
    end

    it "(symbolize_key: true)"do
      a = {a: 1, "b" => 2}
      b = build(a: 1, b: 2)

			expect(@optimism._convert_hash(a, symbolize_key: true)).to eq(b)
    end

    it "do a deep convert (symbolize_key: true)" do
      a = {a: 1, b: {"c" => 2}}
      b = build(a: 1, b: build(c: 2))
      expect(@optimism._convert_hash(a, symbolize_key: true)).to eq(b)
    end

    it "(symbolize_key: false)" do
      a = {a: 1, b: {"c" => 2}}
      b = build(a: 1, b: build("c" => 2))
			expect(@optimism._convert_hash(a, symbolize_key: false)).to eq(b)
    end
  end

  describe "#initialize" do # 1
    it "(hash)" do
      a = Optimism.new(a: 1)
      r = build(a: 1)

      expect(a).to eq(r)
    end

    it "(Optimism)" do
      a = Optimism.new(build(a: 1))
      r = build(a: 1)

      expect(a).to eq(r)
    end

    it "{ block }" do
      Optimism.any_instance.should_receive(:_parse!)
      Optimism.new do "guten" end
    end

    it "(str)" do
      Optimism.any_instance.should_receive(:_parse!).with("guten")
      Optimism.new("guten")
    end
  end

  describe "#_data" do 
  end

	context "access" do
		before :each do
			@a = Optimism({a: 1, b: {c: 2}})
		end

    describe "#<name>" do
      it do
        expect(@a.a).to eq(1)
        expect(@a.b.c).to eq(2)
      end

      it "-> <#Optimism> node when key doesn't exist" do
        expect(@a.z).to be_an_instance_of(Optimism)
      end
    end

    describe "#<name>?" do
      it do
        expect(@a.a?).to be_true
        expect(@a.z?).to be_false
      end
    end

    describe "#[]" do
      it do
        @a = Optimism({a: 1, "b" => 2})

        expect(@a[:a]).to eq(1)
        expect(@a["a"]).to eq(1)

        expect(@a[:b]).to eq(2)
        expect(@a["b"]).to eq(2)

        expect(@a[:z]).to be_nil
        expect(@a["z"]).to be_nil
      end

      it "(symbolize_key: false)" do
        @a = Optimism({a: 1, "b" => 2}, symbolize_key: false)

        expect(@a[:a]).to eq(1)
        expect(@a["a"]).to be_nil


        expect(@a[:b]).to be_nil
        expect(@a["b"]).to eq(2)

        expect(@a[:z]).to be_nil
        expect(@a["z"]).to be_nil
      end
    end
	end

	context "assignment" do
		before :each do
			@a = Optimism()
		end

    describe "#<name>=" do
      it do
        @a.a = 1
        expect(@a.a).to eq(1)
      end

      it "(complex)" do
        @a.a.b = 1
        expect(@a.a.b).to eq(1)
      end
    end

    describe "#[]=" do
      it do
        @a[:a] = 2
        expect(@a[:a]).to eq(2)
        expect(@a["a"]).to eq(2)

        @a["a"] = 3
        expect(@a[:a]).to eq(3)
        expect(@a["a"]).to eq(3)
      end


      it "(symbolize_key: false)" do
        @a = Optimism.new(nil, symbolize_key: false)

        @a[:a] = 2
        expect(@a[:a]).to eq(2)
        expect(@a["a"]).to be_nil

        @a["a"] = 3
        expect(@a[:a]).to eq(2)
        expect(@a["a"]).to eq(3)
      end
    end
	end

	context "path" do
    before :all do
      @a = Optimism({b: {c: {d: 2}}})
    end

    describe "#_" do
      it do
        expect(@a.b._).to eq(@a.b)
      end
    end

    describe "#_parent" do
      it do
        expect(@a.b.c._parent).to eq(@a.b)
      end
    end

    describe "#_root" do
      it do
        expect(@a.b.c._root).to eq(@a)
      end
    end

    describe "#__ (relative path)" do
      it do
        expect(@a.b.__).to eq(@a)
      end

      it "wrong path" do
        expect(@a.___).to eq(nil)
      end
    end

    describe "#_split_path" do
      it do
        expect(@optimism._split_path("foo")).to eq(["_", "foo"])
        expect(@optimism._split_path("foo.bar.baz")).to eq(["foo.bar", "baz"])
      end
    end

    describe "#_walk_down" do
      before :all do
        @o = Optimism({a: {b: {c: {d: 1}}}})
      end

      it do
        node = @o._walk_down("a.b")

        expect(node._name).to eq("b")
      end

      it "-> nil if path is wrong" do 
        node = @o._walk_down("a.z")

        expect(node).to be_nil
      end

      it "(build: true)" do
        o = Optimism.new
        node = o._walk_down("a.b", build: true)

        expect(o).to eq(Optimism(a: {b: Optimism.new}))
      end
    end

    describe "#_walk_up" do
      before :all do
        @o = Optimism({a: {b: {c: {d: 1}}}})
      end

      it do
        node = @o._walk_down("a.b.c")._walk_up("b.a")

        expect(node._name).to eq("a")
      end

      it "(build: true)" do
        o = Optimism.new
        node = o._walk_up("b.a", :build => true)

        expect(node).to eq(Optimism(a: {b: Optimism.new}))
      end
    end

    describe "_walk" do
      it do
        o = Optimism({a: {b: {c: {d: 1}}}})
        a = o._walk_down("a")
        c = o._walk_down("a.b.c")

        expect(a._walk("_")._name).to eq("a")
        expect(a._walk("-_")._name).to eq("a")
        expect(a._walk("b.c")._name).to eq("c")
        expect(c._walk("-b.a")._name).to eq("a")
      end
    end

    xdescribe "#_walk!.  DEAD LOOP" do
      it do
        o = Optimism.new
        o._walk!("a.b", :build => true)
        expect(o._root).to eq(Optimism(a: {b: Optimism.new}))

        o = Optimism.new
        o._walk!("-b.a", :build => true)
        expect(o).to eq(Optimism(a: {b: Optimism.new}))
      end
    end

    describe "#_has_key?" do
      before :all do
        @a = Optimism({a: {b: 1}})
      end

      it "(key)" do
        @a._has_key?("a").should be_true
        @a._has_key?(:a).should be_true
      end

      it "(path)" do
        @a._has_key?("a.b").should be_true
        @a._has_key?("a.z").should be_false
      end

      it "with {symbolize_key: false} option" do
        a = Optimism({a: 1, "b" => 2}, symbolize_key: false)

        a._has_key?(:a).should be_true
        a._has_key?("a").should be_false

        a._has_key?("b").should be_true
        a._has_key?(:b).should be_false
      end
    end

=begin

    describe "#_fetch" do
      before :each do
        @a = Optimism({a: {b: {c: 1}}})
      end

      it "works" do
        expect(@a._fetch("a.b.c")).to eq(1)
      end

      it "return default value when path doesn't exists" do
        expect(@a._fetch("b.c.d",  2)).to eq(2)
        expect(@a[:b][:c][:d]).to eq(2)
      end
    end

    describe "#_store" do
      before :each do
        @a = Optimism.new
      end

      it "works with default :build is true" do
        @a._store 'a.b', 1
        expect(@a).to eq(Optimism({a: {b: 1}}))
      end

      it "works with :build => false" do
        expect{@a._store('a.b', 1, :build => false)}.to raise_error(Optimism::EPath)
      end
    end
=end
  end

	context "computed attribute" do
		it do
      a = Optimism(
        count: lambda{|n| n},
        bar: proc{|n| n}
      )

      expect(a.count(1)).to eq(1)
      expect(a.bar).to be_an_instance_of(Proc)
		end
	end

  context "semantic" do
    it do
      a = Optimism do
        _.is_ok = yes
      end

      expect(a.is_ok).to be_true
    end
  end

  describe "#to_hash" do
    it do
      a = Optimism(a: 1)
      b = {a: 1}

      expect(a.to_hash).to eq(b)
    end
  end

  describe "#_<method> (hash method)" do
    it "goto _data" do
      o = Optimism(a: 1)

      o.stub(:_data){ double.tap{|x| x.should_receive(:foo?)} }
      o._foo?()

      o.stub(:_data){ double.tap{|x| x.should_receive(:foo)} }
      o._foo()
    end
  end


=begin

  describe "#_repalce" do
    it "works" do
      a = Optimism({foo: {bar: 1}})
      b = Optimism.new
      b._replace a.foo
      b.should == Optimism(bar: 1)
      b._root.should == a
    end
  end

  context "marshal" do
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
      @a = Optimism do |c|
        c.a = 1
        c.b.c = 2
      end
    }

    it "works" do
      @a._get("a").should == 1
    end

    it "support path" do
      @a._get("b.c").should == 2
    end

    it "return nil if path is not exists" do
      @a._get("c.d").should == nil
    end

    it "return nil if path is wrong" do
      @a._get("a.b").should == nil
    end
  end


  ## path
  ##

  describe "#_root" do
    it "works" do
      o = Optimism({a: {b: {c: 1}}})
      o.a.b._root.should == o
    end
  end

  describe "#initialize" do # 2
    it "(x, default: 0)" do
      o = Optimism.new({a: 1}, default: 0) 

      expect(o[:a]).to eq(1)
      expect(o[:b]).to eq(0)
    end

    it "(x, symbolize_key: true)" do
      o = Optimism.new({a: 1, "b" => 2}, symbolize_key: true)

      expect(o[:a]).to eq(1)
      expect(o["a"]).to eq(1)

      expect(o["b"]).to eq(2)
      expect(o[:b]).to eq(2)

      o[:c] = 3 
      o["d"] = 4

      expect(o[:c]).to eq(3)
      expect(o["c"]).to eq(3)

      expect(o["d"]).to eq(4)
      expect(o[:d]).to eq(4)
    end

    it "(x, symbolize_key: false)" do
      o = Optimism.new({a: 1, "b" => 2}, symbolize_key: false)
      o[:a] = 1
      o["a"] = 2

      expect(o[:a]).to eq(1)
      expect(o["a"]).to eq(2)
    end

    it %~(x, namespace: "a.b")~ do
      o = Optimism.new({c: 1}, namespace: "a.b") 
      r = Optimism.new({a: {b: {c: 1}}})

      expect(o).to eq(r)
    end
  end
=end
end
