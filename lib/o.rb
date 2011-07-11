libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

=begin

=end

class O
	autoload :VERSION, "o/version"

	Error = Exception.new 
	LoadError = Exception.new(Error)

	BUILTIN_METHODS = [ :p, :pd, :raise, :sleep, :rand, :srand, :exit, :require, :at_exit, :autoload, :open]

	class O_Eval
		class << self
			def eval content=nil, &blk
				o_eval = O_Eval.new nil
				content ? o_eval.instance_eval(content) : o_eval.instance_eval(&blk)
				o_eval._root
			end
		end

		undef_method *BUILTIN_METHODS

		# for <#O_Eval>
		attr_accessor :_root, :_child, :_parent

		# for <#O>. each <#O_Eval> has a <#O>
		attr_accessor :_o

		def initialize root
			@_root = root
			@_child = {}
		end

		def _parent
			@_parent || nil
		end

		def _root
			@_root || self
		end

		def _o
			@_o || O.new
		end

		# a.b.c 1
		#   ROOT -> a -> b -> c is obj
		#   ROOT -> a -> b is <#O_Eval>  
		#   ROOT -> a is <#O_Eval>
		#
		# a 1
		#   ROOT -> a : 1
		def method_missing name, *args, &blk
			O.pd 'o_eval missing', name
			#O.pd name, args, blk
		
			
			# O.p a

			# .name
			# .name &blk
			#
			# a.b
			if args.empty?


				next_o_eval = O_Eval.new(_root)
				next_o_eval._parent = self
				self._child[name] = next_o_eval
				next_o_eval.instance_eval(&blk) if blk

				next_o_eval._o = _o._append(O.new)

				return next_o_eval

			# .name value 
			# a 1
			# a.b.c 1
			else
				O.pd 'a 1', name, args
				self._child[name] = args[0]
				#_o._child[name] = args[0]
				#return _o
			end

		end

		def _data
			_data = {}
			self.instance_variables.each do |k|
				key = k[1..-1].to_sym
				value = self.instance_variable_get(k)
				_data[key] = value 
			end
			_data
		end

		#
		# <#Node 
		#   :b => 1
		#   :c => 2
		#   :d => <#Node
		#     :c => 2>> 
		def inspect(indent="  ")
			o={rst: ""}
			o[:rst] << "<#O_Eval\n"
			_child.each do |k,v|
				o[:rst] << "#{indent}#{k.inspect} => "
				o[:rst] << (O_Eval === v ? "#{v.inspect(indent+"  ")}\n" : "#{v.inspect}\n")
			end
			o[:rst].rstrip! << ">"
		end

	end

	class << self

		public *BUILTIN_METHODS 

		def eval content=nil, &blk
			o = O.new nil
			content ? o.instance_eval(content) : o.instance_eval(&blk)
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
		# first try name.rb, then use name
		#
		# @example
		#   option = O.load("~/.gutenrc")
		#
		#   option = O.load("/absolute/path/a.rb")
		#   
		#   O::Path << "/home"
		#   option = O.load("guten")  #=> try guten.rb; then try guten
		#   option = O.load("guten.rb")
		#
		# @param [String] name
		# @return [O]
		def load name
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

			 O_Eval.eval File.read(path)
		end
	end

	attr_accessor :_parent, :_child, :_root

	def initialize default=nil, options={}, &blk
		@_root = options[:_root]
		@_child = Hash.new(default)
		instance_eval &blk if blk
	end

	def _root
		@_root || self
	end

	def []= key, value
		key = key.respond_to?(:to_sym) ? key.to_sym : key
		@_child[key] = value
	end

	def [] key
		key = key.respond_to?(:to_sym) ? key.to_sym : key
		@_child[key]
	end

	def _child= obj
		@_child = O.get(obj)
	end

	def _merge! obj
		_child.merge! O.get(obj)
		self
	end

	def _merge obj
		data = _child.merge(O.get(obj))
		O.new(data)
	end

	def _replace obj
		@_child = O.get(obj)
		self
	end

	def _dup
		o = O.new
		o._child = _child.dup
		o
	end

	def + other
		raise Error, "not support type for + -- #{other.inspect}" unless O === other
		O.new(_child, other._child)
	end

	# append a new node<#O> to current node<#O>, and move to next node.
	# @param [O] o
	# @return [O] next_o
	def _append next_o
		next_o._parent = self
		self._child[name] = next_o
		next_o
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
		pd 'missing', name, args, blk

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

		# a.c  # return data if has :c
		# a.c {}  # create new <#O> if no :c and has a block
		# a.c  # if no :c, reverse travel the tree to find :c
		#
		elsif args.empty?
			if @_child.has_key?(name)
				return @_child[name]

			else
				next_o = O.new(nil, {_root: _root})
				next_o._parent = self
				self._child[name] = next_o
				next_o.instance_eval(&blk) if blk
				#next_o._o = _o._append(O.new)
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

	private


end
