#
# internal: store data in a Hash, the key of the Hash is always converted to symbol.
#
# Example
#
#   option = O.new
#
#   # assigment
#   option["a"] = 1
#   option[:a] = 1
#   option.a = 1
#
#   # access
#   option["a"] 
#   option[:a] 
#   option.a 
#   option.a? #=> true
#
#   #access Hash methods.
#   option._keys #=> [:a]
#
# assign default value
#
#   option = O.new
#   option.a #=> nil
#
#   option = O.new 0
#   option.a #=> 0
#
# another syntax
#
#   option = O do
#     base = 1
#     @a = base
#     @b = base + 1
#   end
#   option.a #=> 1 
#   option.b #=> 2
#
#
# read option from a file
#
#   # ~/.gutenrc
#   @a = 1
#
#   option = O.load("~/.gutenrc")
#   option.a #=> 1
#
# configuration file
# ------------------
#
# use instance variable to export field.
#
#   base = 1
#   @a = base 
#   @b = O do
#     p @a #=> nil   # instance variable can't pass into block
#     p base #=>  1  # local variable can pass into block
#     @a = base + 1
#   end
#   
#   # after O.load(file)
#   option.a #=> 1
#   option.b.a #=> 2
#
#
class O < Hash
	# PATH for O.load
	PATH = []
	Error = Exception.new 
	LoadError = Exception.new(Error)

	class O_Eval
		def _data
			_data = {}
			self.instance_variables.each do |k|
				key = k[1..-1].to_sym
				value = self.instance_variable_get(k)
				_data[key] = value 
			end
			_data
		end
	end

	class << self
		# convert <#Hash> to <#O>
		#
		# @param [hash] hash
		# @return O
		def from_hash hash
			o = O.new
			o._replace hash
		end

		# load a configuration file,
		# support PATH, and '~/.gutenrc'
		#
		# first try name.rb, then use name
		#
		# @example
		#   option = O.load("~/.gutenrc")
		#   
		#   O::Path << "/home"
		#   option = O.load("guten")  #=> try guten.rb; then try guten
		#   option = O.load("guten.rb")
		#
		# @param [String] name
		# @return [O]
		def load name
			path = nil
			if name =~ /^~/
				file = File.expand_path(name)
				path = file if File.exists?(file)
			else
				catch :break do
					PATH.each  do |p|
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

			eval_file path
		end

		# relative load a configuration file
		# @see load
		#
		# @param [String] name
		# @return [O] option
		def relative_load name
			#pd caller
			a,file, line, method = caller[0].match(/^(.*):(\d+):.*`(.*)'$/).to_a
			raise LoadError, "#{type} is called in #{file}" if file=~/\(.*\)/ # eval, etc.

			file = File.readlink(file) if File.symlink?(file)

			path = nil
			[".rb", ""].each do |ext|
				f = File.absolute_path(File.join(File.dirname(file), name+ext))
				if File.exists?(f)
					path = f
					break
				end
			end

			raise LoadError, "can't find file -- #{name}" unless path

			eval_file path
		end

		private
		def eval_file path
			content = File.open(path){|f| f.read}
			o_eval = O_Eval.new
			o_eval.instance_eval(content)
			O.from_hash(o_eval._data)
		end

	end

	attr_reader :_data

	def initialize default=nil, &blk
		@_data = Hash.new(default)
		if blk
			o_eval = O_Eval.new
			o_eval.instance_eval &blk
			@_data.merge!(o_eval._data)
		end
	end

	def []= key, value
		@_data[key.to_sym] = value
	end

	def [] key
		@_data[key.to_sym]
	end

	def + other
		O.new(@_data, other._data)
	end

	def _replace data
		case data
		when Hash
			@_data = data
		when O
			@_data = data._data
		end
		self
	end

	#
	# _method goes to @_data.send(_method, ..)
	# method? #=> !! @_data[:method]
	# method #=> @_data[:method]
	# method=value #=> @_data[:method]=value
	#
	def method_missing method, *args, &blk
		if method =~ /(.*)=$/
			@_data[$1.to_sym] = args[0]
		elsif method =~ /(.*)\?$/
			!! @_data[$1.to_sym]
		elsif method =~ /^_(.*)/
			@_data.send($1.to_sym, *args, &blk)
		else
			@_data[method]
		end
	end

	def inspect 
		rst = "<#O "
		@_data.each do |k,v|
			rst << "#{k}:#{v} "
		end
		rst << " >" 
	end

end

module Kernel
	def O default=nil, &blk
		O.new(default, &blk)
	end
end
