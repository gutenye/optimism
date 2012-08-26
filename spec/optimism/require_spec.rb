require "spec_helper"

Require = Optimism::Require
public_all_methods Require, Require::ClassMethods

describe Require do
  describe ".find_file" do
    before(:all) {
      @rc_path = File.join($spec_dir, "data/rc.rb")
    }

    it "finds an absolute path" do
      expect(Optimism.find_file(@rc_path)).to eq(@rc_path)
    end

    it "finds a name path" do
      expect(Optimism.find_file("data/rc")).to eq(@rc_path)
    end

    it "loads a home path" do
      ENV["HOME"] = $spec_dir
      expect(Optimism.find_file("~/data/rc.rb")).to eq(File.join(ENV["HOME"], "data/rc.rb"))
    end

    it "finds ./relative/path" do
      Dir.chdir($spec_dir)
      expect(Optimism.find_file("./")).to eq($spec_dir)
    end

    it "finds ../relative/path" do
      Dir.chdir($spec_dir)
      expect(Optimism.find_file("../")).to eq(File.expand_path("../", $spec_dir))
    end
  end

  describe ".require_file" do
    it "works on :merge with :replace" do
      o = Optimism.require_file("data/mixin_a", "data/mixin_b", :merge => :replace)
      expect(o).to eq(Optimism({a: {b: 2, c: "foo", d: "bar"}}))
    end

    it "works on :merge with :ignore" do
      o = Optimism.require_file("data/mixin_a", "data/mixin_b", :merge => :ignore)
      expect(o).to eq(Optimism({a: {b: 1, c: "foo", d: "bar"}}))
    end

    it "not raise EMissingFile by default" do
      expect{ Optimism.require_file("data/file_not_exists") }.not_to raise_error(Optimism::EMissingFile)
    end
  end

  describe ".require_file!" do
    it "raise EMissingFile" do
      expect{ Optimism.require_file!("data/file_not_exists") }.to raise_error(Optimism::EMissingFile)
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
      expect(o).to eq(Optimism({a: "1"}))
    end

    it "with :case_sensive option" do
      o = Optimism.require_env("A", :case_sensive => true)
      expect(o).to eq(Optimism({A: "1"}))
    end

    it "support block, convert value to integer." do
      o = Optimism.require_env("A") { |a|
        a.to_i
      }
      expect(o).to eq(Optimism({a: 1}))
    end

    it "load multiplate environment variables at once" do
      o = Optimism.require_env("A", "B")
      expect(o).to eq(Optimism({a: "1", b: "2"}))
    end

    it "load by pattern" do
      o = Optimism.require_env(/OPTIMISM_(.*)/)
      expect(o).to eq(Optimism({a: "1", b_c: "2"}))
    end

    it "load by pattern, but env not exists" do
      o = Optimism.require_env(/ENV_NOT_EXISTS__(.)/)
      expect(o).to eq(Optimism.new)
    end

    it "load by pattern with :split" do
      o = Optimism.require_env(/OPTIMISM_(.*)/, :split => "_")
      expect(o).to eq(Optimism({a: "1", b: {c: "2"}}))
    end

  end

  describe ".require_input" do
    it "works" do
      Optimism.stub(:gets){ "guten\n" }

      silence { @a = Optimism.require_input("what's your name?", "my.name") }
      expect(@a).to eq(Optimism({my: {name: "guten"}}))
    end

    it "with :default option" do
      Optimism.stub(:gets){ "\n" }

      silence{ @a = Optimism.require_input("what's your name?", "my.name", default: "foo") }
      expect(@a).to eq(Optimism({my: {name: "foo"}}))
    end

    it "call with block" do
      Optimism.stub(:gets){ "1\n" }

      silence{ @a = Optimism.require_input("how old are you?", "age") { |age| age.to_i } }
      expect(@a).to eq(Optimism({age: 1}))
    end
  end

  describe "#_require_input" do
    it "works" do
      Optimism.stub(:gets){ "fine\n" }

      o = Optimism.new
      silence{ o.a.b._require_input "how are you?", "status" }
      expect(o.a.b.status).to eq("fine")
    end

    it "with default value" do
      Optimism.stub(:gets){ "\n" }

      o = Optimism do
        my.status = "well"
      end
      silence{ o.my._require_input "how are you?", "status" }
      expect(o.my.status).to eq("well")
    end
  end
end
