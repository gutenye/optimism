#
# internal: store data in a Hash, the key of the Hash is always converted to symbol.
#
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
			if name =~ /^~/
				file = File.expand_path(name)
				path = file if File.exists?(file)
			elsif File.absolute_path(name) == name
				path = name if File.exists?(name)
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
			pd caller if $TEST
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

	def _merge! data
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
			method = $1.to_sym
			args.map!{|arg| O===arg ? arg._data : arg} 
			rst = @_data.send(method, *args, &blk)

			if [:merge!].include method
				self
			elsif [:merge].include method
				O.new(rst)
			end
		else
			@_data[method]
		end
	end

	def inspect 
		rst = "<#O "
		@_data.each do |k,v|
			rst << "#{k}:#{v.inspect} "
		end
		rst << " >" 
	end

	alias to_s inspect

end

module Kernel
	def O default=nil, &blk
		O.new(default, &blk)
	end
end
