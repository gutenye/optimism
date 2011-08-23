require 'hike'

libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

%w(
  semantics
  hash_method_fix 
  parser
  require
).each { |n| require "optimism/#{n}" }

# <#Optimism> is a node, it has _child, _parent and _root attribute.
#
#  Rc = Optimism do
#    a.b 1
#    a.c do
#      d 2
#    end
#  end
#
#  p Rc
#  #=> <#Optimism
#     :a => <#Optimism
#       :b => 1
#       :c => <#Optimism
#         :d => 2>>>
#
#  Rc.a #=> <#Optimism>
#  Rc.a._child #=> {:b => 1, :c => <#Optimism>}
#  Rc.a._parent #=> is Rc
#  Rc.a._root #=> is Rc
#
#  Rc._parent #=>  nil
#  Rc._root #=> is Rc
#
class Optimism
  autoload :VERSION, "optimism/version"

  Error         = Class.new Exception 
  MissingFile   = Class.new Error

  BUILTIN_METHODS = [:p, :raise, :sleep, :rand, :srand, :exit, :require, :at_exit, :autoload, :open, :send]

  class << self
    public *BUILTIN_METHODS 

    include Require

    # eval a file/string configuration.
    #
    # @params [String] content
    # @return [Optimism] configuration
    def eval(content=nil, &blk)
      optimism = Optimism.new nil

      if content
        optimism._parse_string content
      elsif blk
        optimism.instance_eval(&blk)
      end

      optimism.__send__ :_collect_instance_variables

      optimism._root
    end

    # deep convert Hash to optimism
    # 
    # @example
    #   hash2optimism({a: {b: 1})
    #   #=> Optimism[a: Optimism[b: 1]]
    #
    # @param [Hash,Optimism] hash
    # @return [Optimism]
    def convert(hash)
      return hash if Optimism === hash

      node = Optimism.new
      hash.each { |k,v|
        if Hash === v
          node[k] = convert(v)
        else
          node[k] = v
        end
      }
      node
    end

    # convert Hash to Optimism
    #
    # @param [Optimism,Hash] data
    # @return [Optimism]
    def [](data)
      case data
      when Optimism
        data
      when Hash
        optimism = Optimism.new
        optimism._child = data
        optimism
      end
    end

    # get Hash data from any object
    #
    # @param [Optimism, Hash] obj
    # @return [Hash] 
    def get(obj)
      case obj
      when Hash
        obj
      when Optimism
        obj._child
      end
    end
  end

  undef_method *BUILTIN_METHODS
  include Semantics
  include HashMethodFix
  include RequireInstanceMethod

  # parent node, a <#Optimism>
  attr_accessor :_parent 

  # child node, a hash data
  attr_accessor :_child 
  alias _data _child
  alias _data= _child=

  # root node, a <#Optimism>
  attr_accessor :_root

  # @param [Object] (nil) default create a new hash with the defalut value
  def initialize(default=nil, options={}, &blk)
    @_root = options[:_root] || self # first time is self.
    @_parent = options[:_parent]
    @_child = Hash.new(default)

    self._eval(&blk)

  end

  # a temporarily change
  def _temp(&blk)
    data = _child.dup
    blk.call
    self._child = data

    self
  end

  def _parent
    @_parent || nil
  end

  def _root
    @_root || self
  end

  def _child=(obj)
    @_child = Optimism.get(obj)
  end

  def _eval(content=nil, &blk)
    if blk
      method = _blk2method(&blk)
      blk.arity == 0 ?  method.call : method.call(self)
      _collect_instance_variables
      _fix_lambda_values
    end
  end

  # set data
  #
  # @example
  #  
  #  o = Optimism.new
  #
  #  a = Optimism do
  #    _.b = 1
  #  end
  #
  #  o[:a] = a OR o.a << a  #=> o.a.b is 1
  #
  def []=(key, value)
    key = key.respond_to?(:to_sym) ? key.to_sym : key

    if Optimism === value
      value._parent = self
      value._root = self._root
    end

    @_child[key] = value
  end

  # get data
  def [](key)
    key = key.respond_to?(:to_sym) ? key.to_sym : key

    @_child[key]
  end

  def ==(other)
    case other 
    when Optimism
      _child == other._child
    else
      false
    end
  end

  # duplicate
  #
  # @return [Optimism] new <#Optimism>
  def _dup
    optimism = Optimism.new
    optimism._child = _child.dup

    optimism
  end

  # replace with a new data
  #
  # @param [Hash,Optimism] obj
  # @return [Optimism] self
  def _replace(obj)
    self._child = Optimism.get(obj)

    self
  end

  def +(other)
    raise Error, "not support type for + -- #{other.inspect}" unless Optimism === other

    Optimism.new _child, other._child
  end

  # everything goes here.
  #
  #   .name? 
  #   .name= value 
  #   .name value 
  #   ._name
  #
  #   .c 
  #   .a.b.c
  #
  def method_missing(name, *args, &blk)
    # path: root
    if name == :_
      return _root

    # relative path: __
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

    # ._name
    elsif name =~ /^_(.*)/
      name = $1.to_sym
      args.map!{|arg| Optimism===arg ? arg._child : arg} 
      return @_child.send(name, *args, &blk)

    # .name?
    elsif name =~ /(.*)\?$/
      return !! @_child[$1.to_sym]

    elsif Proc === @_child[name]
      return @_child[name].call(*args)

    # a.c  # return data if has :c
    # a.c  # create new <#Optimism> if no :c 
    #
    elsif args.empty?

      # a.b.c 1
      # a.b do
      #   c 2
      # end
      if @_child.has_key?(name)
        optimism = @_child[name]
        optimism.instance_eval(&blk) if blk
        return optimism

      else
        next_optimism = Optimism.new(nil, {_root: _root, _parent: self})
        self._child[name] = next_optimism
        next_optimism._eval(&blk)
        return next_optimism
      end

    # .name value
    else
      @_child[name] = args[0]
      return args[0]
    end
  end

  # pretty print
  # 
  #   <#Optimism 
  #     :b => 1
  #     :c => 2
  #     :d => <#Optimism
  #       :c => 2>> 
  def inspect(indent="  ")
    rst = ""
    rst << "<#Optimism\n"
    _child.each { |k,v|
      rst << "#{indent}#{k.inspect} => "
      rst << (Optimism === v ? "#{v.inspect(indent+"  ")}\n" : "#{v.inspect}\n")
    }
    rst.rstrip! << ">"

    rst
  end

  def _parse_string(content)
    bind = binding

    vars = Parser.collect_local_variables(content)
    content = Parser.compile(content)
    eval content, bind

    vars.each { |name|
      value = bind.eval(name)
      @_child[name.to_sym] = value
    }
  end

  def _eval(content)
    content=_rstrip_content(content)
    @_child = Optimism.eval(content)._child
  end

  alias to_s inspect

private
  # convert block to method.
  #
  #   you can call a block with arguments
  #
  # @example USAGE
  #   instance_eval(&blk)
  #   blk2method(&blk).call *args
  #
  def _blk2method(&blk)
    self.class.class_eval {
      define_method(:__blk2method, &blk)
    }

    method(:__blk2method)
  end

  # strip left wide-space each line
  def _rstrip_content(content)
    content.split("\n").each.with_object("") { |line, memo|
      memo << line.rstrip + "\n"
    }
  end

  def _collect_instance_variables
    instance_variables.each { |name|
      # skip @_child ..
      next if name =~ /^@_/

      value = instance_variable_get(name)
      @_child[name[1..-1].to_sym]=value
    } 
  end

  def _fix_lambda_values
    @_child.each { |k,v|
      if Proc==v and v.lambda? 
        @_child[k] = v.call
      end
    }
  end

end

module Kernel
  # a handy method 
  def Optimism(default=nil, &blk)
    Optimism.new default, &blk
  end
end
