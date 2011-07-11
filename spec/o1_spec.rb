require "spec_helper"

class O
	attr_reader :_data
end

o = O.relative_load "data/lib/test"
p o._data

describe O do
	before :each do
		@o = O.new
		@o[:a] = 1
	end

	describe "#[]=" do
		it "converts key to symbol" do
			@o["b"] = 2
			@o._data[:b].should == 2
		end
	end

	describe "#[]" do
		it "converts key to symbol" do
			@o["a"].should == 1
		end
	end

	describe "#method_missing" do
		it "calls #key" do
			@o.a.should == 1
		end

		it "calls #key?" do
			@o.a?.should == true
		end

		it "calls #key=" do
			@o.b = 2
			@o._data[:b].should == 2
		end

		it "calls #_method" do
			@o._keys.should == [:a]
		end


	end

	describe ".new" do
		it "has default value" do
			O.new.a.should == nil
			O.new(1).a.should == 1
		end
		it "retrive a block" do
			o = O.new do
				base = 1
				@a = base
				@b = base + 1
			end
			o.a.should == 1
			o.b.should == 2
		end
	end

	describe ".load" do
		it "support ~/path" do
			ENV["HOME"] = File.join($spec_dir, "data/home")
			o = O.load("~/gutenrc")
			o._data.should == {a: 1}
		end

		it "support PATH" do
			O::PATH << File.join($spec_dir, "data/lib")

			o = O.load("tag.rb")
			o._data.should == {a: 1}

			o = O.load("guten")
			o._data.should == {a: 1}

		end
	end

	describe ".relative_load" do
		o = O.relative_load "data/lib/guten"
		o._data.should == {a: 1}

		o = O.relative_load "data/lib/tag.rb"
		o._data.should == {a: 1}
	end

end

describe O::O_Eval do
	it "works" do
		o = O::O_Eval.new
		o.instance_eval <<-EOF
			@a = 1
		EOF

		o._data.should == {a: 1}
	end
end

describe "#O" do
	option = O do
		@a = 1
	end
	option._data.should == {a: 1}
end
