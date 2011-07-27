O, a configuration gem for Ruby
====================================

**Homepage**: [https://github.com/GutenYe/o](https://github.com/GutenYe/o) <br/>
**Author**:	Guten <br/>
**License**: MIT-LICENSE <br/>
**Documentation**: [http://rubydoc.info/gems/o/frames](http://rubydoc.info/gems/o/frames) <br/>
**Issue Tracker**: [https://github.com/GutenYe/o/issues](https://github.com/GutenYe/o/issues) <br/>

The name `o` comes from option/setting, short and handy, eh-ah~

Features
--------

* Variable and computed attribute support
* Pure Ruby DSL syntax
* Multiple configuration levels including system, user, and command-line.
* Hash compatibility

Introduction
-------------

The three levels of configuration include system, user, and cmdline:

	APP/lib/guten/rc.rb   # system level
	~/.gutenrc        # user level
	$ guten --list or ENV[GEMFILE]=x guten  # cmdline level

	module Guten
		Rc = O.require("guten/rc") + O.require("~/.gutenrc") # require use $:
		Rc.list = true or Rc.gemfile = ENV[GEMFILE] # from cmdline.
	end

	a constant works very well in many places, but you are free to use any variable.

### An example ###

	Rc = O do
		host "localhost"
		port 8080
		mail.stmp.address "stmp.gmail.com"

		my.development do  # namespace
			adapter "postgresql"
			database "hello_development"
			username "guten"
		end

		time proc{|offset| Time.now} # computed attribute
	end

### An example using alternative syntax ###

	Rc = O do |c|
		c.host = "localhost"
		c.port = 8080
		c.mail.stmp.address "stmp.gmail.com"

		my.development do |c|
			c.adapter = "mysql2"
			c.database = "hello"
			c.username = "guten"
		end

		c.time = proc{|offset| Time.now}
	end

### An example of some sugar syntax. _works in a file only_ ###

	# file: guten/rc.rb
	development:
		adapter "mysql2"
		database "hello"
		username "guten"

	#=>

	development do
		adapter "mysql2"
		database "hello"
		username "guten"
	end



**NOTE**: This is not pure ruby syntax, but it works.
In order for this to work, a tab ("\t") must be used for indention.

### Initialize ###

In order to initialize the configuration object either of the two ways can be used.

	Rc = O.new
	Rc = O.require "guten/rc"  # from file
	Rc = O do 
		a 1 
	end
	Rc = O[a: 1]  # from a hash data
	Rc._merge!(a: 1)

file: "guten/rc.rb"

	a 1

Initalize with a default value

	Rc = O.new
	p Rc[:hello] #=> nil
	Rc = O.new 1
	p Rc[:hello] #=> 1
	p Rc.hello #=> <#O>  be careful here

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
	O do |c|
		age 2
		c.age = 2
		c[:age] = 2
	end

### Node ###

	Rc = O.new
	Rc.a.b.c = 1
	p Rc.a.b.c #=> <#Fixnum 1>
	p Rc.a.b   #=> <#O>
	p Rc.a     #=> <#O>
	p Rc.i.dont.exists #=> <#O>

	Rc = O.new
	p Rc.a._empty? #=> true  # if a node is empty?
	Rc.a.b = 1
	p Rc.a._empty? #=> false
	p O===Rc.a     #=> true  # if it is a node?
	p O===Rc.a.b   #=> false

### Variable & Path ###

	O do
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

	O do
		mail.stmp.address "stmp.gmail.com"
		mail.stmp do
			address "stmp.gmail.com"
		end
	end

Another namespace example:

	O do
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

	Rc = O do
		time proc{|n| Time.now}
	end
	p Rc.time # print current time. no need Rc.time.call()
	p Rc.time(2) # call time
	Rc.time = 2 # assign new value
	p Rc[:time] #=> <#Proc>

### Semantic ###

	O do
		is_started no # yes ...
	end

Note: for a list of semantic methods, see O::Semantics

### Hash compatibility ###

Internal, datas are stored as a Hash. You can access all hash methods via `_method`

	Rc = O.new
	Rc.a = 1
	Rc._child #=> {:a=>1}

	Rc._keys #=> [:a]

### Temporarily change ###

	Rc.a = 1
	Rc._temp do
		Rc.a = 2
	end
	p Rc.a #=> 1


### Access built-in method inside block ###

	Rc = O do
		sleep 10     # is a data. Rc.sleep #=> 10
		O.sleep 10   # call builtin 'sleep' method
	end

Note: for a list of blocked methods, see O::BUILTIN_METHODS

### Additional examples ###

	O do
		name do
			first "Guten"
			last  "Ye"
			is    "#{first} #{last}"
		end
	end

\# file: a.rb

	c = self
	c.host = "localhost"
	c.port = 8080
	c.name do |c|
		c.first = "Guten"
	end

Contributing
-------------

* Feel free to join the project and make contributions (by submitting a pull request)
* Submit any bugs/features/ideas to github issue tracker
* Codeing style: https://gist.github.com/1105334

Install
----------

	gem install o

Resources
---------

* [konfigurator](https://github.com/nu7hatch/konfigurator) Small and flexible configuration toolkit inspired i.a. by Sinatra settings
* [configatron](https://github.com/markbates/configatron) A super cool, simple, and feature rich configuration system for Ruby apps 
* [simpleconfig](https://github.com/lukeredpath/simpleconfig) make application-wide configuration settings easy to set and access in an object-oriented fashion
* [configuration](https://github.com/ahoward/configuration) pure ruby scoped configuration files 

Copyright
---------
Copyright &copy; 2011 by Guten. this library released under MIT-LICENSE, See {file:LICENSE} for futher details.
