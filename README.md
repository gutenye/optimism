Optimism, a configuration gem for Ruby
====================================

| Homepage:      | https://github.com/GutenYe/optimism
|----------------|--------------------------------------
| Author:	       | Guten 
| License:       | MIT-LICENSE 
| Documentation: | http://rubydoc.info/gems/optimism/frames
| Issue Tracker: | https://github.com/GutenYe/optimism/issues

a proposal to [simply the syntax](https://github.com/GutenYe/optimism/issues/9) in 3.0.

Features
--------

* Variable and computed attribute support
* DSL syntax
* Multiple configuration levels including system, user, and command-line.
* Hash compatibility

Introduction
-------------

The three levels of configuration include system, user, and realtime:

* /etc/foo or APP/lib/foo/rc.rb # system
* ~/.foorc        # user
* `$ foo --list` or `$ ENV[GEMFILE]=x foo`  # realtime

for example

	module Foo
		Rc = Optimism.require %w(foo/rc ~/.foorc)
		Rc.list = true or Rc.gemfile = ENV[GEMFILE] # from cmdline.
	end

### An example ###

	Rc = Optimism do
		host "localhost"
		port 8080
		mail.stmp.address "stmp.gmail.com"

		my.development do  # namespace
			adapter "postgresql"
			database "hello_development"
			username "foo"
		end

		time proc{|offset| Time.now} # computed attribute
	end

### An example using alternative syntax ###

	Rc = Optimism do |c|
		c.host = "localhost"
		c.port = 8080
		c.mail.stmp.address "stmp.gmail.com"

		my.development do |c|
			c.adapter = "mysql2"
			c.database = "hello"
			c.username = "foo"
		end

		c.time = proc{|offset| Time.now}
	end

### An example of some sugar syntax. _works in a file only_ ###

	# file: foo/rc.rb
	development:
		adapter "mysql2"
		database "hello"
		username "foo"

	#=>

	development do
		adapter "mysql2"
		database "hello"
		username "foo"
	end


**NOTE**: This is not pure ruby syntax, but it works.
In order for this to work, a tab ("\t") must be used for indention.

### Initialize ###

In order to initialize the configuration object either of the two ways can be used.

	Rc = Optimism.new
	Rc = Optimism.require "foo/rc"  # from file
	Rc = Optimism do 
		a 1 
	end
	Rc = Optimism[a: 1]  # from a hash data

	Rc = Optimism.new
	Rc.production << {a: {b: 1}} #=> Rc.production.a.b is 1 
	Rc.production << Optimism.require_string("port 8080") #=> Rc.production.port is 1

Initalize with a default value

	Rc = Optimism.new
	p Rc[:hello] #=> nil
	Rc = Optimism.new(1)
	p Rc[:hello] #=> 1
	p Rc.hello #=> <#Optimism>  be careful, it's a node.

### Assignment & Access ###

Flexibility has been built in to allow for various ways to assign configuration 
data values and access the same values within your application. Here are some
examples of how this can be done:

Assignment:

	Rc.age 1
	Rc.age = 1
	Rc[:age] = 1
	Rc["age"] = 1

Access:

	Rc.age    #=> 1
	Rc.age?   #=> true
	Rc[:age]  #=> 1
	Rc["age"] #=> 1
	--- 
	Optimism do |c|
		age 2
		c.age = 2
		c[:age] = 2
	end

### Node ###

	Rc = Optimism.new
	Rc.a.b.c = 1
	p Rc.a.b.c #=> <#Fixnum 1>
	p Rc.a.b   #=> <#Optimism>
	p Rc.a     #=> <#Optimism>
	p Rc.i.dont.exists #=> <#Optimism>

	Rc = Optimism.new
	p Rc.a._empty? #=> true  # if a node is empty?
	Rc.a.b = 1
	p Rc.a._empty? #=> false
	p Optimism===Rc.a     #=> true  # if it is a node?
	p Optimism===Rc.a.b   #=> false

### Variable & Path ###

	Optimism do
		age 1
		p age  #=> 1
		my do
			age 2
			friend do
				age 3
				p age     #=> 3
				p __.age  #=> 2  __ is relative up to 1 times
				p ___.age #=> 1  ___ and so on is relative up to 2 and so on times
				p _.age   #=> 1  _ is root
			end
		end
	end

### Namespace ###

Either way is fine:

	Optimism do
		mail.stmp.address "stmp.gmail.com"
		mail.stmp do
			address "stmp.gmail.com"
		end
	end

Another namespace example:

	Optimism do
		age 1 

		my do
			age 2 
		end

		my.friend do
			age 3 
		end
	end


### Group ###

Use namespace or use some separate files like rails.

	config/
		applications.rb
		environments/
			development.rb
			test.rb
			production.rb

### Computed attribute ###

	Rc = Optimism do
		time proc{|n| Time.now}
	end
	p Rc.time # print current time. no need Rc.time.call()
	p Rc.time(2) # call time
	Rc.time = 2 # assign new value
	p Rc[:time] #=> <#Proc>

### Semantic ###

	Optimism do
		is_started no # yes ...
	end

Note: for a list of semantic methods, see Optimism::Semantics

### Hash compatibility ###

Internal, datas are stored as a Hash. You can access all hash methods via `_method`

	Rc = O.new
	Rc.a = 1
	Rc._child #=> {:a=>1}

	Rc._keys #=> [:a]

### Require ###

load configuration from  file. support $:

	Optimism.require %w(
		foo/rc
		~/.foorc
	end

load configuration from string

	Optimism.require_string <<-EOF
		my.age = 1
	EOF
	

load configuration from environment variable

	ENV[OPTIMISM_A_B] = 1
	Rc = Optimism.require_env(/OPTIMISM_(.*)/) #=> Rc.a_b is 1
	Rc = Optimism.require_env(/OPTIMISM_(.*)/, split: '_') #=> Rc.a.b is 1

load configuration from user input

	Rc = Optimism.require_input("what's your name?", "my.name") #=> Rc.my.name is whatever you typed in terminal

### Temporarily change ###

	Rc.a = 1
	Rc._temp do
		Rc.a = 2
	end
	p Rc.a #=> 1


### Access built-in method inside block ###

	Rc = Optimism do
		sleep 10     # is a data. Rc.sleep #=> 10
		Optimism.sleep 10   # call builtin 'sleep' method
	end

Note: for a list of blocked methods, see Optimism::BUILTIN_METHODS

### Additional examples ###

	Optimism do
		name do
			first "Guten"
			last  "Ye"
			is    "#{first} #{last}"
		end
	end

	Optimism do
		_.name = "foo"
		my.name = "bar"  # _ is optional here.
	end

\# file: a.rb

	_.host = "localhost"
	_.port = 8080
	_.name do |c|
		c.first = "Guten"
		c.last = "Tag"
	end

	my.host = "localhost"
	my.port = 8080

Contributing
------------

* Feel free to join the project and make contributions (by submitting a pull request)
* Submit any bugs/features/ideas to github issue tracker
* Coding Style Guide: https://gist.github.com/1105334

Contributors
------------

This project wouldn’t exist without all of our awesome users and contributors. 

* [View our growing list of contributors](https://github.com/GutenYe/optimism/contributors)

Thank you so much!

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
