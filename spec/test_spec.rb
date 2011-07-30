require 'spec_helper'

describe Optimism do
	it 'works' do
o = Optimism.new

o.a << {:log => {:enabled => true}}

#p o.a
	end
end
