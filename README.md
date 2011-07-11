O, a configuration libraray for Ruby
====================================

**Homepage**: [https://github.com/GutenYe/o](https://github.com/GutenYe/o) <br/>
**Author**:	Guten <br/>
**License**: MIT-LICENSE <br/>
**Documentation**: [http://rubydoc.info/gems/o/frames](http://rubydoc.info/gems/o/frames) <br/>
**Issue Tracker**: [https://github.com/GutenYe/o/issues](https://github.com/GutenYe/o/issues) <br/>

completed documentation: localhost.com/guten

Features
--------

* support variable, computed attribute
* DSL syntax in pure ruby
* tree way to do configration.
* hash compatibility

Introduction
-------------

do configuration at three levels: system, user, cmdline

1. lib/guten/rc.rb 
2. ~/.gutenrc
3. $ guten --list
	
	module Guten
		Rc = O.require("guten/rc") + O.require("~/.gutenrc")
		Rc.list = 12
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

	Rc = O.new
	Rc = O.require "guten/rc"  # from file
	Rc = O do 
		a 1 
	end
	Rc = O[a:1]  # from hash   
	Rc._merge! O_or_Hash  



### assignment & access ###

either way is fine

	Rc.age 1
	Rc.age 1
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
	p Rc.a.b.c #=> 1
	p Rc.a.b   #=> <#O>
	p Rc.a     #=> <#O>
	p Rc.i.dont.exists #=> nil # by O.new(default=nil)

### variable & path ###

	age 1
	myage age 
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

### namespace ###

	mail.stmp.address "stmp.gmail.com"
	mail.stmp do
		address "stmp.gmail.com"
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
		time proc{|Time.now}
	end
	p Rc.time # print current time. no need Rc.time.call()

### semantic ###

	is_started no # yes ...


### hash compatibility ###

	Rc._keys # access hash method via `_method`

### temporarily change ###

	Rc.a = 1
	Rc._temp do
		Rc.a = 2
	end
	p Rc.a #=> 1


### access builtin method inside block ###

	O do
		O.p 1   # call builtin's 'p' method
		self.p = 12
	end

### another sugar syntax ###

this way is experiment.

	development do
		adapter "mysql2"
		databse "hello"
		username "guten"
	end

	#=>

	development:
		adapter "mysql2"
		database "hello"
		username "guten"
		

### some other Examples ###

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
