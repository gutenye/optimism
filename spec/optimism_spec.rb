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
    @aptimism = Optimism.new
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
      @a = Optimism.new
    end

    it do
      a = {a: 1, b: {c: {d: 2}}}
      ret = @aptimism._convert_hash(a)

      expect(ret[:b]._name).to eq("b")
      expect(ret[:b].c._parent._name).to eq("b")
    end

    it "(symbolize_key: true)"do
      a = {a: 1, "b" => 2}
      b = build(a: 1, b: 2)

			expect(@aptimism._convert_hash(a, symbolize_key: true)).to eq(b)
    end

    it "do a deep convert (symbolize_key: true)" do
      a = {a: 1, b: {"c" => 2}}
      b = build(a: 1, b: build(c: 2))
      expect(@aptimism._convert_hash(a, symbolize_key: true)).to eq(b)
    end

    it "(symbolize_key: false)" do
      a = {a: 1, b: {"c" => 2}}
      b = build(a: 1, b: build("c" => 2))
			expect(@aptimism._convert_hash(a, symbolize_key: false)).to eq(b)
    end
  end

  describe "#initialize" do
    it "(hash)" do
      a = Optimism.new(a: 1)
      r = build(a: 1)

      expect(a).to eq(r)
    end

    it "(hash, default: x)" do
      a = Optimism.new({a: 1}, default: 2)

      expect(a._data.default).to eq(2)
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

  describe "#_merge!" do
    before :each do
      @a = Optimism({a: 1, b: 2})
    end

    it "(hash)" do
      @a._merge!({a: 3, c: 4})
      r = Optimism({a: 3, b: 2, c: 4})

      expect(@a).to eq(r)
    end

    it "(optimism)" do
      @a._merge!(Optimism({a: 3, c: 4}))
      r = Optimism({a: 3, b: 2, c: 4})

      expect(@a).to eq(r)
    end

    xit "(string) NEED PARSER" do  
      @a._merge!(<<-EOF)
a = 3
c = 4
     EOF
      r = Optimism({a: 3, b: 2, c: 4})

      expect(@a).to eq(r)
    end

    it "is deep merge" do
      a = Optimism({a: {b: 1, c: "foo"}, b: {c: "x"}})
      b = Optimism({a: {b: 2, d: "bar"}})
      r = Optimism({a: {b: 2, c: "foo", d: "bar"}, b: {c: "x"}})

      a._merge! b
      expect(a).to eq(r)
    end
  end

  describe "#_merge" do
    it do
      o = Optimism({a: 1, b: 2})
      ret = o._merge(Optimism({a: 3, c: 4}))
      r = Optimism({a: 3, b: 2, c: 4})

      expect(o).to eq(o)
      expect(ret).to eq(r)
    end
  end

  describe "#_repalce" do
    it "root node" do
      a = Optimism({a: 1})
      b = Optimism({b: {c: 2}})
      r = Optimism({c: 2})

      a._replace(b.b)
      expect(a).to eq(r)
      expect(a._name).to eq("")
      expect(a._parent).to be_nil
    end

    it "sub node" do
      a = Optimism({a: {a1: 1}})
      b = Optimism({b: 2})
      r = Optimism({a: {b: 2}})

      a.a._replace(b)
      expect(a).to eq(r)
      expect(a.a._name).to eq("a")
      expect(a.a._parent).to eq(r)
    end
  end

  describe "#_dup" do
    it do
      a = Optimism({a: 1})
      b = a.dup
      r = Optimism({a: 2})

      b[:a] = 2
      expect(a).to eq(a)
      expect(b).to eq(r)
    end
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

      it "asign a node" do
        a = Optimism({a: 1})
        b = Optimism({b1: 2})
        r = Optimism({a: 1, b: {b1: 2}})

        a[:b] = b
        expect(a).to eq(r)
        expect(b._parent).to eq(r)
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

    describe "#_parent=" do
      it do
        a = Optimism({a: {a1: 1}})
        b = Optimism({b: {b1: 2}})
        r = Optimism({a: {a1: 1, b: {b1: 2}}})

        b.b._parent = a.a
        expect(b.b._root).to eq(r)
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
        expect(@aptimism._split_path("foo")).to eq(["_", "foo"])
        expect(@aptimism._split_path("foo.bar.baz")).to eq(["foo.bar", "baz"])
      end
    end

    describe "#_walk_down" do
      before :all do
        @a = Optimism({a: {b: {c: {d: 1}}}})
      end

      it do
        node = @a._walk_down("a.b")

        expect(node._name).to eq("b")
      end

      it "(reverse: true)" do
        node = @a._walk_down("b.a", reverse: true)

        expect(node._name).to eq("b")
      end

      it "-> nil if path is wrong" do 
        node = @a._walk_down("a.z")

        expect(node).to be_nil
      end

      it "(build: true)" do
        a = Optimism.new
        r = Optimism({a: {b: Optimism.new}})
        node = a._walk_down("a.b", build: true)

        expect(node).to eq(r.a.b)
        expect(node._root).to eq(r)
      end
    end

    describe "#_walk_up" do
      before :all do
        @a = Optimism({a: {b: {c: {d: 1}}}})
        @a = @a._walk_down("a.b.c")
      end

      it do
        node = @a._walk_up("b.a")

        expect(node._name).to eq("a")
      end

      it "(reverse: true)" do
        node = @a._walk_up("a.b", reverse: true)

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

    describe "#_walk_down!" do
      it do
        a = Optimism({a: {b: {c: 1}}})
        r = Optimism({c: 1})

        a._walk_down!("a.b")
        expect(a).to eq(r)
      end

      it "(build: true)" do
        a = Optimism.new
        r = Optimism({a: {b: Optimism.new}})

        a._walk_down!("a.b", build: true)
        expect(a).to eq(r.a.b)
        expect(a._root).to eq(r)
      end


      it "raise EPath when wrong path" do
        a = Optimism.new

        expect{a._walk_down!("a.b")}.to raise_error(Optimism::EPath)
      end
    end

    describe "#_walk_up!" do
      it do
        a = Optimism({a: 1})
        r = Optimism({b: {c: {a: 1}}})

        a._walk_up!("c.b", :build => true)
        expect(a).to eq(r)
      end

      it "raise EPath when wrong path" do
        a = Optimism.new

        expect{a._walk_up!("c.b")}.to raise_error(Optimism::EPath)
      end
    end

    describe "#_walk!" do
      before :each do
        o = Optimism({a: {b: {c: {d: 1}}}})
        @a = o._walk_down("a")
        @c = o._walk_down("a.b.c")
      end

      it { @a._walk!("_");    expect(@a._name).to eq("a") }
      it { @a._walk!("-_");   expect(@a._name).to eq("a") }
      it { @a._walk!("b.c");  expect(@a._name).to eq("c") }
      it { @c._walk!("-b.a"); expect(@c._name).to eq("a") }
    end
  end

  context "hash method" do
    describe "#to_hash" do
      it do
        a = Optimism(a: 1)
        b = {a: 1}

        expect(a.to_hash).to eq(b)
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

    describe "#_fetch" do
      before :each do
        @a = Optimism({a: 1, "b" => 2, c: {d: {e: 3, "f" => 4}}})
        @b = Optimism({a: 1, "b" => 2, c: {d: {e: 3, "f" => 4}}}, symbolize_key: false)
      end

      it "(key)" do
        expect(@a._fetch(:a)).to eq(1)
        expect(@a._fetch("a")).to eq(1)

        expect(@a._fetch("b")).to eq(2)
        expect(@a._fetch(:b)).to eq(2)
      end

      it "(key) with (symbolize_key: false) options" do
        expect(@b._fetch(:a)).to eq(1)
        expect(@b._fetch("a", nil)).to be_nil

        expect(@b._fetch("b")).to eq(2)
        expect(@b._fetch(:b, nil)).to be_nil
      end

      it "(path)" do
        expect(@a._fetch("c.d.e")).to eq(3)
        expect(@a._fetch("c.d.f")).to eq(4)
      end

      it "(path, default=2)" do
        expect(@a._fetch("z.a",  2)).to eq(2)
      end

      it "(path) raise error without default" do
        expect{@a._fetch("z.a")}.to raise_error(KeyError)
      end
    end

    describe "#_store" do
      before :each do
        @a = Optimism.new
        @b = Optimism.new(nil, symbolize_key: false)
      end

      it "(key)" do
        @a._store(:a, 1)
        expect(@a[:a]).to eq(1)

        @a._store("a", 2)
        expect(@a[:a]).to eq(2)
      end

      it "(key) with (symbolize_key: false)" do
        @b._store(:a, 1)
        @b._store("a", 2)

        expect(@b[:a]).to eq(1)
        expect(@b["a"]).to eq(2)
      end

      it "(path)" do
        @a._store("a.b", 1)

        expect(@a.a.b).to eq(1)
      end
    end

    describe "#_delete" do
      it "(key)" do
        a = Optimism({a: 1, b: 2})
        r = Optimism({b: 2})

        expect(a._delete("a")).to eq(1)
        expect(a).to eq(r)
      end

      it "(key) with (symbolize_key: false) options" do
        a = Optimism({a: 1}, symbolize_key: false)

        expect(a._delete("a")).to be_nil
        expect(a._delete(:a)).to eq(1)
      end

      it "(key) when key not found" do
        a = Optimism({a: 1})

        expect(a._delete(:z)).to be_nil
        expect(a._delete(:z){3}).to eq(3)
      end

      it "(path)" do
        a = Optimism({a: {b: {c: 1, d: 2}}})
        r = Optimism({a: {b: {d: 2}}})

        expect(a._delete("a.b.c")).to eq(1)
        expect(a).to eq(r)
      end

      it "(path) when path not found" do
        a = Optimism({a: {b: 1}})

        expect(a._delete("a.z.x")).to be_nil
        expect(a._delete("a.z.x"){3}).to eq(3)
      end
    end

    describe "#_<method>" do
      it "goto _data" do
        o = Optimism(a: 1)

        o.stub(:_data){ double.tap{|x| x.should_receive(:foo?)} }
        o._foo?()

        o.stub(:_data){ double.tap{|x| x.should_receive(:foo)} }
        o._foo()
      end
    end
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
end
