# Optimism, a configuration gem for Ruby [![Build Status](https://secure.travis-ci.org/GutenYe/optimism.png)](http://travis-ci.org/GutenYe/optimism)

| Homepage:      | https://github.com/GutenYe/optimism
|----------------|--------------------------------------
| Author:	       | Guten 
| License:       | MIT-LICENSE 
| Documentation: | http://rubydoc.info/gems/optimism/frames
| Issue Tracker: | https://github.com/GutenYe/optimism/issues

Note: not support ruby1.8, jruby, rubinius

Features
--------

* Variable and computed attribute support
* DSL syntax
* Multiple configuration levels including system, user, and command-line.
* Hash compatibility

Introduction
-------------

Load configurations from system and home directory.

	module Foo
		Rc = Optimism.require %w(/etc/foo ~/.foorc)
	end

### Ruby-stynax ###

	Rc = Optimism do |c|
		c.host = "localhost"
		c.port = 8080
		c.mail.stmp.address = "stmp.gmail.com"

		my.development do |c|  # namespace
			c.adapter = "postgresql"
			c.database = "hello_development"
			c.username = "foo"
		end

		c.time = lambda{ |offset| Time.now } # computed attribute
	end

### String-syntax ###

	Rc = Optimism <<-EOF
		host = "localhost"
		port = 8080
		mail.stmp.address = "stmp.gmail.com"

		my.development:
			adapter = "postgresql"
			database = "hello_development"
			username = "foo"

		time = lambda{ |offset| Time.now }
	EOF

### Assignment & Access ###

Flexibility has been built in to allow for various ways to assign configuration 
data values and access the same values within your application. Here are some
examples of how this can be done:

	# Assignment:
	Rc = Optimism.new
	Rc.age = 1     # It's same as Rc[:age] = 1
	Rc[:age] = 2
	Rc["age"] = 3
	# Access:
	Rc.age    #=> 2 # It's same as Rc[:age]
	Rc[:age]  #=> 2
	Rc["age"] #=> 3
	Rc.age?   #=> true


### Node ###

	Rc = Optimism do
		a.b = 1
	end
	p Rc.a.b  #=> <#Fixnum 1>
	p Rc.a    #=> <#Optimism>
	p Rc      #=> <#Optimism>
	p Rc.i.dont.exists #=> <#Optimism>
	p Rc.foo?  #=> false
  p Rc._has_key?(:foo) #=> false
	p Rc[:foo] #=> nil

### Variable & Path ###

	Optimism <<-EOF
		age = 1

		my:
			age = 2

			friend:
				age = 3

				my_friend_age = age      #=> 3
				my_age        = __.age   #=> 2  __ is relative up to 1 times
				root_age      = ___.age  #=> 1  ___ and so on is relative up to 2 and so on times
				root_age      = _.age    #=> 1 _ is root
				Optimism.p _.age         # this won't work, path only woks in assignment
	EOF
	

### Computed attribute ###

Computed attribute is a lamda object, you don't need to invoke `#call` expilict.

	Rc = Optimism do |c|
		c.time = lambda{ |n| Time.now }
	end
	p Rc.time   # => 2011-08-26 16:29:16 -0800
	p Rc[:time] # => <#Proc>

### Semantic ###

	Optimism do |c|
		c.start = yes
	end

Note: for a list of semantic methods, see Optimism::Semantics

### Hash compatibility ###

Internal, datas are stored as a Hash. You can access all hash methods via `_method` way.

	Rc = Optimism do |c|
		c.a = 1
	end
	p Rc._data #=> {:a => 1}
	p Rc._keys #=> [:a]

### Load configurations ###

Load configurations from files. It uses $:

	Rc = Optimism.require %w(
		foo/rc       # APP/lib/foo/rc.rb
		~/.foorc
	)

Load configurations from environment variables.

	ENV[OPTIMISM_A_B] = 1
	Rc = Optimism.require_env(/OPTIMISM_(.*)/) #=> Rc.a_b is 1
	Rc = Optimism.require_env(/OPTIMISM_(.*)/, :split => "_") #=> Rc.a.b is 1

load configurations from user input.

	Rc = Optimism.require_input("what's your name?", "my.name") #=> Rc.my.name is foo

### Access built-in method inside block ###

	Rc = Optimism do |c|
		p 1            # doesn't work
		p.a = 1        # p is a <#Optimism> node
		Optimism.p 1   # works
	end

Note: for a list of blocked methods, see Optimism::BUILTIN_METHODS

### More examples ###

	rc = Optimism <<-EOF
		group:
			# nil
	EOF

	rc.group #=> <#Optimism>


Contributing
------------

* Feel free to join the project and make contributions (by submitting a pull request)
* Submit any bugs/features/ideas to github issue tracker
* Coding Style Guide: https://gist.github.com/1105334

Contributors
------------

* [contributors](https://github.com/GutenYe/optimism/contributors)

Install
----------

	gem install optimism

Resources
---------

* [konfigurator](https://github.com/nu7hatch/konfigurator) Small and flexible configuration toolkit inspired i.a. by Sinatra settings
* [configatron](https://github.com/markbates/configatron) A super cool, simple, and feature rich configuration system for Ruby apps 
* [simpleconfig](https://github.com/lukeredpath/simpleconfig) make application-wide configuration settings easy to set and access in an object-oriented fashion
* [configuration](https://github.com/ahoward/configuration) pure ruby scoped configuration files 

Copyright
---------

(MIT-LICENSE)

Copyright (c) 2011 Guten

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
