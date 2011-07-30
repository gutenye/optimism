require "spec_helper"

describe Optimism do

  describe "#_merge!" do
    it "works" do
      o = Optimism.new

      o.b._merge! a: 1
      o.should == Optimism[b: Optimism[a: 1]]

      o.b._merge! Optimism[a: 2]
      o.should == Optimism[b: Optimism[a: 2]]
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
      o.should == Optimism[a: Optimism[b: 2, c: "foo", d: "bar"], b: Optimism[c: "x"]]
    end
  end

  describe "#_merge" do
    it "works" do
      o = Optimism.new
      new = o._merge a: 1
      o.should == o
      new.should == Optimism[a: 1]
    end
  end

  describe "#_get" do
    before(:all) {
      @o = Optimism do
        _.a = 1
        _.b.c = 2
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
