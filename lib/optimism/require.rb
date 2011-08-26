class Optimism
  module Require
    # load configuration from file
    #
    # use $: and support home path like '~/.foorc'.
    # by defualt, it ignore missing files.
    #
    # @example
    #
    #   Optimism.require "foo" # first try guten/rc, then try guten/rc.rb 
    #
    #   Optimism.require %w(
    #     /etc/foo
    #     ~/.foorc
    #   ) 
    #
    #   # with option :namespace. add a namespace 
    #   Rc = Optimism <<-EOF, :namespace => 'a.b'
    #     c.d = 1
    #     e.f = 2
    #   EOF
    #   # =>  Rc.a.b.c.d is 1
    #
    #   # add to an existing configuration object.
    #   Rc = Optimism.new
    #   Rc.a.b << Optimism("my.age = 1")  #=> Rc.a.b.my.age is 1
    #
    #   # call with block
    #   ENV["AGE"] = "1"
    #   Rc = Optimism.require_env("AGE") { |age| age.to_i }
    #   p Rc.age #=> 1
    #
    #   # option :mixin => :ignore is ignore already exisiting value.
    #   # a.rb
    #     a.b = 1
    #     a.c = "foo"
    #   # b.rb
    #     a.b = 2
    #     a.d = "bar"
    #   Optimism.require %w(a b), :mixin => :ignore 
    #   #=>
    #     a.b is 1
    #     a.c is "foo"
    #     a.d is "bar"
    #   
    # @param [Array,String] name_s
    # @param [Hash] opts
    # @option opts [String] :namespace wrap into a namespace.
    # @option opts [Boolean] :mixin (:replace) :replace :ignore
    # @option opts [Boolean] :ignore_syntax_error not raise SyntaxError 
    # @option opts [Boolean] :raise_missing_file raise MissingFile
    # @return [Optimism]
    #
    # @param [Hash] opts
    def require_file(name_s, opts={})
      opts[:mixin] ||= :replace
      name_s = Array === name_s ? name_s : [name_s]
      error = opts[:ignore_syntax_error] ? SyntaxError : nil

      o = Optimism.new
      name_s.each { |name|
        path = find_file(name, opts) 
        unless path
          raise MissingFile if opts[:raise_missing_file]
          next
        end

        begin
          new = Optimism(File.read(path))
        rescue error
        end

        case opts[:mixin] 
        when :replace
          o << new 
        when :ignore
          new << o
          o = new
        end
      }

      o._walk!('-'+opts[:namespace], :build => true) if opts[:namespace]

      o
    end

    alias require require_file

    # load configuration from environment variables.
    # @see require_file
    #
    # @example
    # 
    #  ENV["A"] = "1"
    #  ENV["OPTIMISM_A] = "a"
    #  ENV["OPTIMISM_B_C] = "b"
    #
    #  # default is case_insensive
    #  require_env("A") #=> Optimism[a: "1"]
    #  require_env("A", case_sensive: true) #=> Optimism[A: "1"]
    #
    #  # with Regexp
    #  require_env(/OPTIMISM_(.*)/) #=> Optimism[a: "a", b_c: "b"]
    #  require_env(/OPTIMISM_(.*), split: "_") #=> Optimism[a: "a", b: Optimism[c: "b"]]
    #
    # @overload require_env(env_s, opts={}, &blk)
    #   @param [String, Array, Regexp] env_s
    #   @param [Hash] opts
    #   @option opts [String] :namespace
    #   @option opts [String] :default # see #initiliaze
    #   @option opts [String, Regexp] :split
    #   @option opts [Boolean] :case_sensive (false)
    #   @return [Optimism] def require_env(*args, &blk)
    def require_env(*args, &blk)
      if Regexp === args[0]
        pat = args[0]
        opts = args[1] || {}
        envs = ENV.each.with_object({}) { |(key,value), memo|
          next unless key.match(pat)
          memo[$1] = key
        }

      elsif String === args[0]
        envs = {args[0] => args[0]} 
        opts = args[1] || {}

      elsif Array === args[0]
        envs = args[0].each.with_object({}) { |v, memo|
          memo[v] = v
        }
        opts = args[1] || {}
      end
      opts[:split] ||= /\Z/

      o = Optimism.new(:default => opts[:defualt])
      envs.each { |path, env|
        path = opts[:case_sensive] ? path : path.downcase
        path = path.split(opts[:split]).join('.')
        value = blk ? blk.call(ENV[env]) : ENV[env]
        o._set2(path, value, :build => true)
      }

      o._walk!('-'+opts[:namespace], :build => true) if opts[:namespace]

      o
    end

    # get configuration from user input. 
    # @ see require_input
    #
    # @example
    #   
    #   o = require_input("what's your name?", "my.name", default: "foo")
    #   o.my.name #=> get from user input or "foo"
    #
    # @param [String] msg print message to stdin.
    # @param [String] key
    # @param [Hash] opts
    # @option opts [Object] :namespace
    # @option opts [Object] :default use this default if user doesn't input anything.
    # @return [Optimism]
    def require_input(msg, path, opts={}, &blk)
      default = opts[:default] ? "(#{opts[:default]})"  : ""
      opts[:build] = opts.has_key?(:build) ? opts[:build] : true
      print msg+default
      value = gets.strip
      value = value.empty? ? opts[:default] : value
      value = blk ? blk.call(value) : value
      o = Optimism.new
      o._set2 path, value, opts

      o._root
    end

  private
    def find_file(name, opts={})
      path = nil

      # ~/.gutenrc
      if name =~ /^~/
        file = File.expand_path(name)
        path = file if File.exists?(file)

      # /absolute/path/to/rc
      elsif File.absolute_path(name) == name
        path = name if File.exists?(name)

      # relative/rc
      else
        hike = Hike::Trail.new
        hike.extensions.push ".rb"
        hike.paths.replace $:
        path = hike.find(name)
      end

      path
    end
  end

  module RequireInstanceMethod

    # a shortcut for Require#require_input
    # @see Require#require_input
    # @see Optimism#_walk
    #
    # @example
    #
    #  o = Optimism do
    #    _.my.age = 1
    #  end
    #  o._require_input("how old are you?", "my.age") # use a default value with 1
    #
    # @param [Hash] opts
    # @option opts [Boolean] :build 
    def _require_input(msg, key, opts={}, &blk)
      opts[:default] ||= _get(key)
      opts[:build] ||= false
      self << Optimism.require_input(msg, key, opts, &blk)
      self
    end
  end
end
