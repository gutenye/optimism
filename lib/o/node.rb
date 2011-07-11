module O

	class Node_Eval
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

	class Node
		attr_accessor :_parent, :_child

		def initialize default=nil, &blk
			@_child = Hash.new(default)
			if blk
				o_eval = Node_Eval.new
				o_eval.instance_eval &blk
				@_child.merge!(o_eval._data)
			end
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
			@_child = _get(obj)
		end

		# get #_child from obj
		#
		# @param [String, Node, Hash] obj
		#
		# @return [Hash] #_child
		def _get obj
			case obj
			when Hash
				obj
			when Node
				obj.child
			when String
				xx
			end
		end

		def _merge! obj
			_child.merge! _get(obj)
			self
		end

		def _merge obj
			data = _child.merge(_get(obj))
			Node.new(data)
		end

		def _replace obj
			@_child = _get(obj)
			self
		end

		def + other
			raise Error, "not support type for + -- #{other.inspect}" unless Node === other
			Node.new(_child, other._child)
		end


		#
		# _name goes to @_child.send(_name, ..)
		# name? #=> !! @_child[:name]
		# name #=> @_child[:name]
		# name, value #=> @_child[:name] = value
		# name=value #=> @_child[:name]=value
		#
		def method_missing name, *args, &blk
			pd 'missing', name
			# name=
			if name =~ /(.*)=$/
				@_child[$1.to_sym] = args[0]

			# name?
			elsif name =~ /(.*)\?$/
				!! @_child[$1.to_sym]

			# _name
			elsif name =~ /^_(.*)/
				name = $1.to_sym
				args.map!{|arg| O===arg ? arg._child : arg} 
				rst = @_child.send(name, *args, &blk)


			# name, value
			elsif args
				@_child[name] = x

			# name
			else
				@_child[name]
			end
		end

		#
		# <#Node 
		#   :b => 1
		#   :c => 2
		#   :d => <#Node
		#     :c => 2>> 
		def inspect(indent="  ")
			o={rst: ""}
			o[:rst] << "<#Node\n"
			_child.each do |k,v|
				o[:rst] << "#{indent}#{k.inspect} => "
				o[:rst] << (Node === v ? "#{v.inspect(indent+"  ")}\n" : "#{v.inspect}\n")
			end
			o[:rst].rstrip! << ">"
		end

		alias to_s inspect

	end
end
