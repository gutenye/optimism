O, a configuration libraray for Ruby
====================================

**Homepage**: [https://github.com/GutenYe/o](https://github.com/GutenYe/o) <br/>
**Author**:	Guten <br/>
**License**: MIT-LICENSE <br/>
**Documentation**: [http://rubydoc.info/gems/o/frames](http://rubydoc.info/gems/o/frames) <br/>
**Issue Tracker**: [https://github.com/GutenYe/o/issues](https://github.com/GutenYe/o/issues) <br/>

for completed documentation, see [localhost.com/not_yet](http://localhost.com/not_yet)

Features
--------

* support variable, computed attribute
* DSL syntax in pure ruby
* tree way to do configration.
* hash compatibility

Introduction
-------------

do configuration at three levels: system, user, cmdline

	lib/guten/rc.rb   # system level
	~/.gutenrc        # user level
	$ guten --list    # cmdline level
		
	module Guten
		Rc = O.require("guten/rc") + O.require("~/.gutenrc")
		Rc.list = true
	end


### a completed example ###

	Rc = O do
		host "localhost"
		port 8080
		mail.stmp.address "stmp.gmail.com"

		my.development do  # namespace
			adapter "mysql2"
			database "hello"
			username "guten"
		end

		time proc{|offset| Time.now} # computed attribute
	end

alternative syntax

	Rc = O do
		c = self
		c.host = "localhost"
		c.port = 8080
		c.mail.stmp.address "stmp.gmail.com"

		my.development do
			c = self
			c.adapter = "mysql2"
			c.database = "hello"
			c.username = "guten"
		end

		c.time = proc{|offset| Time.now}
	end

### initialize ###

either way is fine

	Rc = O.new
	Rc = O.require "guten/rc"  # from file
	Rc = O do 
		a 1 
	end
	Rc = O[a:1]  # from hash   
	Rc._merge! O_or_Hash  

file: "guten/rc.rb"

	a 1


### assignment & access ###

either way is fine

	Rc.age 1
	Rc.age = 1
	Rc[:age] = 1
	Rc["age"] = 1
	---
	Rc.age    #=> 1
	Rc.age?   #=> true
	Rc[:age]  #=> 1
	Rc["age"] #=> 1
	--- 
	O do
		age 2
		self.age = 2
		self[:age] = 2
	end

### node ###

	Rc.a.b.c 1
	p Rc.a.b.c #=> <#Fixnum 1>
	p Rc.a.b   #=> <#O>
	p Rc.a     #=> <#O>
	p Rc.i.dont.exists #=> <#O> #check use #_empty?

### variable & path ###

	O do
		age 1
		p age  #=> 1
		my do
			age 2
			friend do
				age 3
				p age     #=> 3
				p __.age  #=> 2  relative
				p ___.age #=> 1
				p _.age   #=> 1  root
			end
		end
	end

### namespace ###

either way is fine

	O do
		mail.stmp.address "stmp.gmail.com"
		mail.stmp do
			address "stmp.gmail.com"
		end
	end

another example

	O do
		age 1 

		my do
			age 2 
		end

		my.friend do
			age 3 
		end
	end


### group ###

use namespace or use some seperate files like rails.

	config/
		applications.rb
		environments/
			development.rb
			test.rb
			production.rb

### computed attribute ###

	Rc = O do
		time proc{|n| Time.now}
	end
	p Rc.time # print current time. no need Rc.time.call()
	p Rc.time(2) # call time
	Rc.time = 2 # assign new value
	p Rc[:time] #=> <#Proc>

### semantic ###

	O do
		is_started no # yes ...
	end

for a list of semantic methods, see O::Semantics

### hash compatibility ###

	Rc._keys # access hash method via `_method`

### temporarily change ###

	Rc.a = 1
	Rc._temp do
		Rc.a = 2
	end
	p Rc.a #=> 1


### access builtin method inside block ###

	Rc = O do
		sleep 10     # is a data. Rc.sleep #=> 10
		O.sleep 10   # call builtin 'sleep' method
	end

a list of blocked methods is in O::BUILTIN_METHODS

### another sugar syntax ###

it likes yaml-style.  this way is experiment. used in file syntax only

	a do
		b 1
		c do
			d 1
		end
	end

	#=>

	# file: guten/rc.rb
	a:
		b 1
		c:
			d 1

**WARNNING**:  must use \t to indent

### some other examples ###

	name do
		first "Guten"
		last  "Ye"
		is    "#{first} #{last}"
	end


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

* [konfigurator](https://github.com/nu7hatch/konfigurator) Small and flexible configuration toolkit inspired i.a. by Sinatra settings
* [configatron](https://github.com/markbates/configatron) A super cool, simple, and feature rich configuration system for Ruby apps 
* [simpleconfig](https://github.com/lukeredpath/simpleconfig) make application-wide configuration settings easy to set and access in an object-oriented fashion
* [configuration](https://github.com/ahoward/configuration) pure ruby scoped configuration files 

Copyright
---------
Copyright &copy; 2011 by Guten. this library released under MIT-LICENSE, See {file:LICENSE} for futher details.
