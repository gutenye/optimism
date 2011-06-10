O, a configuration libraray for Ruby
====================================

**Homepage**: [https://github.com/GutenLinux/o](https://github.com/GutenLinux/o) <br/>
**Author**:	Guten <br/>
**License**: MIT-LICENSE <br/>
**Documentation**: [http://rubydoc.info/gems/o/frames](http://rubydoc.info/gems/o/frames) <br/>
**Issue Tracker**: [https://github.com/GutenLinux/o/issues](https://github.com/GutenLinux/o/issues) <br/>

Overview
--------

	descripe your prjoect here.

Features
--------

	a clearly list of features.

Introduction
-------------

	option = O.new

	# assigment
	option["a"] = 1
	option[:a] = 1
	option.a = 1

	# access
	option["a"] 
	option[:a] 
	option.a 
	option.a? #=> true

	#access Hash methods.
	option._keys #=> [:a]

assign default value

	option = O.new
	option.a #=> nil

	option = O.new 0
	option.a #=> 0

another syntax

	option = O do
	  base = 1
	  @a = base
	  @b = base + 1
	end
	option.a #=> 1 
	option.b #=> 2


read option from a file

	# ~/.gutenrc
	@a = 1
	@path = Pathname('/home')

	# a.rb
	require "pathname"
	option = O.load("~/.gutenrc")
	option.a #=> 1

configuration file
------------------

 use instance variable to export field.

	base = 1
	@a = base 
	@b = O do
	  p @a #=> nil   # instance variable can't pass into block
	  p base #=>  1  # local variable can pass into block
	  @a = base + 1
	end
	
	# after O.load(file)
	option.a #=> 1
	option.b.a #=> 2

Contributing
-------------

* join the project.
* report bugs/featues to issue tracker.
* fork it and pull a request.
* improve documentation.
* feel free to post any ideas. 

Install
----------

	gem install o

Resources
---------

	some related resources to help each other.

Copyright
---------
Copyright &copy; 2011 by Guten. this library released under MIT-LICENSE, See {file:LICENSE} for futher details.
