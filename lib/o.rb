libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

%w(semantics hash_method_fix parser).each{|n| require "o/#{n}"}

class O
	autoload :VERSION, "o/version"

	Error 		= Class.new Exception 
	LoadError = Class.new Error

	BUILTIN_METHODS = [ :p, :raise, :sleep, :rand, :srand, :exit, :require, :at_exit, :autoload, :open]

	class << self
		public *BUILTIN_METHODS 

		# @params [String] content
		def eval content=nil, &blk
			o = O.new nil
			content ? o.instance_eval(Parser.compile(content)) : o.instance_eval(&blk)
			o._root
		end

		# convert hash, O to O
		# @param [O,Hash] data
		def [] data
			case data
			when O
				data
			when Hash
				o = O.new
				o._child = data
				o
			end
		end

		# get hash data from obj
		#
		# @param [O, Hash] obj
		#
		# @return [Hash] 
		def get obj
			case obj
			when Hash
				obj
			when O
				obj._child
			end
		end

		# load a configuration file,
		# use $: and support '~/.gutenrc'
		#
		# @example
		#   option = O.load("~/.gutenrc")
		#
		#   option = O.load("/absolute/path/a.rb")
		#   
		#   O::Path << "/home"
		#   option = O.load("guten")  #=> try "guten.rb"; then try "guten"
		#   option = O.load("guten.rb")
		#
		# @param [String] name
		# @return [O]
		def require name
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
				catch :break do
					$:.each do |p|
						['.rb', ''].each {|ext|
							file = File.join(p, name+ext)
							if File.exists? file
								path = file
								throw :break
							end
						}
					end
				end
			end

			raise LoadError, "can't find file -- #{name}" unless path

			O.eval File.read(path)
		end
	end

	undef_method *BUILTIN_METHODS
	include Semantics
	include HashMethodFix

	attr_accessor :_parent, :_child, :_root

	def initialize default=nil, options={}, &blk
		@_root = options[:_root]
		@_child = Hash.new(default)

		if blk
			method = _blk2method(&blk)
			if blk.arity == 0
				method.call
			else
				method.call self
			end
		end
	end

	def _temp &blk
		data = _child.dup
		blk.call
		self._child = data
	end

	def _parent
		@_parent || nil
	end

	def _root
		@_root || self
	end

	def _child= obj
		@_child = O.get(obj)
	end

	def []= key, value
		key = key.respond_to?(:to_sym) ? key.to_sym : key
		@_child[key] = value
	end

	def [] key
		key = key.respond_to?(:to_sym) ? key.to_sym : key
		@_child[key]
	end

	def == other
		_child == other._child
	end

	def _dup
		o = O.new
		o._child = _child.dup
		o
	end

	def _replace obj
		self._child = O.get(obj)
		self
	end

	def + other
		raise Error, "not support type for + -- #{other.inspect}" unless O === other
		O.new(_child, other._child)
	end

	# convert block to method.
	#
	#   you can call a block with arguments
	#
	# @example USAGE
	#   instance_eval(&blk)
	#   blk2method(&blk).call *args
	#
	def _blk2method &blk
		self.class.class_eval do
			define_method(:__blk2method, &blk)
		end
		method(:__blk2method)
	end


	#
	# .name? 
	# .name= value 
	# .name value 
	# ._name
	#
	# .c 
	# .a.b.c
	#
	def method_missing name, *args, &blk
		#O.p d 'missing', name, args, blk

		# path: root
		if name == :_
			return _root

		# relative path.
		elsif name =~ /^__+$/
			num = name.to_s.count('_') - 1
			node = self
			num.times {
				return unless node
				node = node._parent
			}
			return node

		# .name=
		elsif name =~ /(.*)=$/
			return @_child[$1.to_sym] = args[0]

		# .name?
		elsif name =~ /(.*)\?$/
			return !! @_child[$1.to_sym]

		# ._name
		elsif name =~ /^_(.*)/
			name = $1.to_sym
			args.map!{|arg| O===arg ? arg._child : arg} 
			return @_child.send(name, *args, &blk)

		elsif Proc === @_child[name]
			return @_child[name].call *args

		# a.c  # return data if has :c
		# a.c  # create new <#O> if no :c 
		#
		elsif args.empty?

			# a.b.c 1
			# a.b do
			#   c 2
			# end
			if @_child.has_key?(name)
				o = @_child[name]
				o.instance_eval(&blk) if blk
				return o

			else
				next_o = O.new(nil, {_root: _root})
				next_o._parent = self
				self._child[name] = next_o
				next_o.instance_eval(&blk) if blk
				return next_o
			end

		# .name value
		else
			@_child[name] = args[0]
			return args[0]
		end
	end

	#
	# <#O 
	#   :b => 1
	#   :c => 2
	#   :d => <#O
	#     :c => 2>> 
	def inspect(indent="  ")
		o={rst: ""}
		o[:rst] << "<#O\n"
		_child.each do |k,v|
			o[:rst] << "#{indent}#{k.inspect} => "
			o[:rst] << (O === v ? "#{v.inspect(indent+"  ")}\n" : "#{v.inspect}\n")
		end
		o[:rst].rstrip! << ">"
	end

	alias to_s inspect
end

module Kernel
	def O default=nil, &blk
		O.new(default, &blk)
	end
end
