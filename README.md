# Optimism, a configuration gem for Ruby [![Build Status](https://secure.travis-ci.org/GutenYe/optimism.png)](http://travis-ci.org/GutenYe/optimism)

|                |                                             |
|----------------|---------------------------------------------|
| Homepage:      | https://github.com/GutenYe/optimism         |
| Author:	       | Guten                                       |
| License:       | MIT-LICENSE                                 |
| Documentation: | http://rubydoc.info/gems/optimism/frames    |
| Issue Tracker: | https://github.com/GutenYe/optimism/issues  |
| Ruby Versions: | Ruby 1.9.3, Rubinius                        |
| Support Syntax: | ruby-syntax, string-syntax, yaml, json, ... |

**Features**

* Variable and computed attribute support
* DSL syntax
* Multiple configuration levels including system, user, and command-line.
* Hash compatibility

Introduction
-------------

Load configurations from system and home directory.

	Rc = Optimism.require("/etc/foo", "~/.foorc")

Load configurations from a yaml file.

	require "yaml"
	Rc = Optimism.require("foo.yml")

**Ruby stynax**

	Rc = Optimism do
		_.host = "localhost"
		_.port = 8080
		_.mail.stmp.address = "stmp.gmail.com"

		my.development do                   # namespace
			_.adapter = "postgresql"
			_.database = "hello_development"
			_.username = "foo"
		end

		_.time = lambda{ |offset| Time.now } # computed attribute
	end

**String syntax**

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

**YAML syntax**

	Rc = Optimism <<-EOF, parser: :yaml
		host: localhost
		port: 8080

		development:
			adapter:  postgresql
			database: hello_development
			username: foo
	EOF

### Assignment & Access 

Flexibility has been built in to allow for various ways to assign configuration 
data values and access the same values within your application. Here are some
examples of how this can be done:

	# Assignment:
	Rc = Optimism.new
	Rc.age = 1     
	Rc[:age] = 2
	Rc["age"] = 3

	# Access:
	Rc.age           #-> 2 
	Rc[:age]         #-> 2
	Rc["age"]        #-> 3
	Rc.age?          #-> true

	Rc._fetch("age", nil)
	Rc._fetch(["my.age", "age"], nil)

	# check
	Rc._has_key?("age")

### Node ###

	Rc = Optimism do
		a.b = 1
	end
	p Rc.a.b               #-> <#Fixnum 1>
	p Rc.a                 #-> <#Optimism>
	p Rc                   #-> <#Optimism>
	p Rc.i.dont.exists     #-> <#Optimism>
	p Rc.foo?              #-> false
	p Rc._has_key?(:foo)   #-> false
	p Rc[:foo]             #-> nil

### Variable & Path ###

	Optimism <<-EOF
		age = 1

		my:
			age = 2

			friend:
				age = 3

				age1 = age               #-> 3
				age2 = _.age             #-> 3  _ is current node
				age3 = __.age            #-> 2  __ is relative up to 1 times
				age4 = ___.age           #-> 1  ___ and so on is relative up to 2 and so on times
				age5 = _r.age            #-> 1  _r is root node
	EOF
	

### Config inheritance

	username = foo
	github:
		username = bar

	p Rc._fetch(["github.username", "username"], nil)   #-> first one avalibale.

### Computed attribute ###

Computed attribute is a lamda object, but you don't need to invoke `#call` expilict.

	Rc = Optimism do
		_.time = lambda{ Time.now }
	end
	p Rc.time            #-> 2011-08-26 16:29:16 -0800
	p Rc[:time]          #-> <#Proc>

### Semantic ###

	Optimism do
		_.start = yes
	end

Note: for a list of semantic methods, see Optimism::Semantics

### Hash compatibility ###

Internal, datas are stored as a Hash. You can access all hash methods via `_method` way.

	Rc = Optimism do
		_.a = 1
	end
	p Rc._data        #-> {:a => 1}
	p Rc._keys        #-> [:a]

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

Install
----------

	gem install optimism

Development [![Dependency Status](https://gemnasium.com/GutenYe/optimism.png?branch=master)](https://gemnasium.com/GutenYe/optimism) [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/GutenYe/optimism)
===========

Write a new parser 
-------------------

\# my_parser.rb

	class MyParser < Base
		def self.parse(optimism, content, opts={}, &blk)
			optimism << YAML.load(content)
		end
	end

	Optimism.add_extension ".yml", MyParser

use the parser

	Optimism.require("foo.yml")
	Optimsm("content", parser: :myparser)

Contributing 
-------------

* Submit any bugs/features/ideas to github issue tracker.

Please see [Contibution Documentation](https://github.com/GutenYe/optimism/blob/master/CONTRIBUTING.md).

A list of [Contributors](https://github.com/GutenYe/optimism/contributors).

Resources
---------

* [confstruct](https://github.com/mbklein/confstruct) Yet another hash/struct-like configuration object for Ruby
* [configatron](https://github.com/markbates/configatron) A super cool, simple, and feature rich configuration system for Ruby apps 

Copyright
---------

(MIT-LICENSE)

Copyright (c) 2011-2012 Guten

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
