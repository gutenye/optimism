O, a configuration/setting libraray for Ruby
====================================

**Homepage**: [https://github.com/GutenYe/o](https://github.com/GutenYe/o) <br/>
**Author**:	Guten <br/>
**License**: MIT-LICENSE <br/>
**Documentation**: [http://rubydoc.info/gems/o/frames](http://rubydoc.info/gems/o/frames) <br/>
**Issue Tracker**: [https://github.com/GutenYe/o/issues](https://github.com/GutenYe/o/issues) <br/>

Introduction
-------------

	option = O.new

	# assigment, either way
	option["a"] = 1
	option[:a] = 1
	option.a = 1

	# access, either way
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

* [configatron](https://github.com/markbates/configatron) A super cool, simple, and feature rich configuration system for Ruby apps 
* [konfigurator](https://github.com/nu7hatch/konfigurator) Small and flexible configuration toolkit inspired i.a. by Sinatra settings
* [configliere](https://github.com/mrflip/configliere) Wise, discreet configuration for ruby scripts: integrate config files, environment variables and command line with no fuss
* [simpleconfig](https://github.com/lukeredpath/simpleconfig) make application-wide configuration settings easy to set and access in an object-oriented fashion
* [configuration](https://github.com/ahoward/configuration) pure ruby scoped configuration files 
* [rconfig](https://github.com/rahmal/rconfig) The complete solution for Ruby Configuration Management <br>
<br>
* [configurator](https://github.com/brennandunn/configurator) Fatten your models with key/value pairs
* [configlet](https://github.com/jbarnette/configlet) Configuration mismanagement.
* [configr](https://github.com/joshnesbitt/configr) A more elegant approach to creating and accessing configuration values
* [config_newton](https://github.com/intridea/config_newton) ConfigNewton is a simple tool for library authors to provide class-level configuration

Copyright
---------
Copyright &copy; 2011 by Guten. this library released under MIT-LICENSE, See {file:LICENSE} for futher details.
