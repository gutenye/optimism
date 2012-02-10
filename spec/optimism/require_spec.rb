require "spec_helper"

module Optimism::Require
  public :find_file
end

describe Optimism::Require do
  describe ".find_file" do
    before(:all) {
      @rc_path = File.join($spec_dir, "data/rc.rb")
    }

    it "finds an absolute path" do
      Optimism.find_file(@rc_path).should == @rc_path
    end

    it "finds a name path" do
      Optimism.find_file("data/rc").should == @rc_path
    end

    it "loads a home path" do
      ENV["HOME"] = $spec_dir
      Optimism.find_file("~/data/rc.rb").should == File.join(ENV["HOME"], "data/rc.rb")
    end

    it "finds ./relative/path" do
      Dir.chdir($spec_dir)
      Optimism.find_file("./").should == $spec_dir
    end

    it "finds ../relative/path" do
      Dir.chdir($spec_dir)
      Optimism.find_file("../").should == File.expand_path("../", $spec_dir)
    end
  end

  describe ".require_file" do
    it "works with :namespace" do
      o = Optimism.require("data/rc", :namespace => "a.b")
      o.should == Optimism[a: Optimism[b: Optimism[a: 1]]]
    end

    it "works on :mixin with :replace" do
      o = Optimism.require("data/mixin_a", "data/mixin_b", :mixin => :replace)
      o.should == Optimism[a: Optimism[b: 2, c: "foo", d: "bar"]]
    end

    it "works on :mixin with :ignore" do
      o = Optimism.require("data/mixin_a", "data/mixin_b", :mixin => :ignore)
      o.should == Optimism[a: Optimism[b: 1, c: "foo", d: "bar"]]
    end

    it "raise InvalidSyntax" do
      lambda{ Optimism.require("data/invalid_syntax") }.should raise_error(Optimism::EParse)
    end

    it "not raise MissingFile by default" do
      lambda { Optimism.require("data/file_not_exists") }.should_not raise_error(Optimism::MissingFile)
    end

    it "raise MissingFile with :raise_missing_file" do
      lambda { Optimism.require("data/file_not_exists", :raise_missing_file => true) }.should raise_error(Optimism::MissingFile)
    end
  end

  describe ".require_env" do
    before(:all) {
      ENV["A"] = "1"
      ENV["B"] = "2"
      ENV["OPTIMISM_A"] = "1"
      ENV["OPTIMISM_B_C"] = "2"
    }

    it "load an environment variable" do
      o = Optimism.require_env("A")
      o.should == Optimism[a: "1"]
    end

    it "with :case_sensive option" do
      o = Optimism.require_env("A", :case_sensive => true)
      o.should == Optimism[A: "1"]
    end

    it "support block, convert value to integer." do
      o = Optimism.require_env("A") { |a|
        a.to_i
      }
      o.should == Optimism[a: 1]
    end

    it "load multiplate environment variables at once" do
      o = Optimism.require_env("A", "B")
      o.should == Optimism[a: "1", b: "2"]
    end

    it "load by pattern" do
      o = Optimism.require_env(/OPTIMISM_(.*)/)
      o.should == Optimism[a: "1", b_c: "2"]
    end

    it "load by pattern, but env not exists" do
      o = Optimism.require_env(/ENV_NOT_EXISTS__(.)/)
      o.should == Optimism.new
    end

    it "load by pattern with :split" do
      o = Optimism.require_env(/OPTIMISM_(.*)/, :split => "_")
      o.should == Optimism[a: "1", b: Optimism[c: "2"]]
    end

  end

  describe ".require_input" do
    it "works" do
      module Optimism::Require
        def gets() "guten\n" end
      end
      o = Optimism.require_input("what's your name?", "my.name")
      o.should == Optimism[my: Optimism[name: "guten"]]
    end

    it "with :default option" do
      module Optimism::Require
        def gets() "\n" end
      end
      o = Optimism.require_input("what's your name?", "my.name", default: "foo")
      o.should == Optimism[my: Optimism[name: "foo"]]
    end

    it "call with block" do
      module Optimism::Require
        def gets() "1\n" end
      end
      o = Optimism.require_input("how old are you?", "age") { |age| age.to_i }
      o.should == Optimism[age: 1]
    end
  end

  describe "#_require_input" do
    it "works" do
      module Optimism::Require
        def gets() "fine\n" end
      end

      o = Optimism.new
      o.a.b._require_input "how are you?", "status"

      o.a.b.status.should == "fine"
    end

    it "with default value" do
      module Optimism::Require
        def gets() "\n" end
      end

      o = Optimism do
        my.status = "well"
      end
      o.my._require_input "how are you?", "status"

      o.my.status.should == "well"
    end
  end
end
