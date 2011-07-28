libdir = File.dirname(__FILE__)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

%w(
  semantics
  hash_method_fix 
  parser
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

  Error     = Class.new Exception 
  LoadError = Class.new Error

  BUILTIN_METHODS = [ :p, :raise, :sleep, :rand, :srand, :exit, :require, :at_exit, :autoload, :open]

  class << self
    public *BUILTIN_METHODS 

    # eval a file/string configuration.
    #
    # @params [String] content
    # @return [Optimism] configuration
    def eval(content=nil, &blk)
      optimism = Optimism.new nil
      content ? optimism.instance_eval(Parser.compile(content)) : optimism.instance_eval(&blk)

      optimism._root
    end

    # convert Hash, Optimism to Optimism
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

    # load a configuration file,
    # use $: and support '~/.gutenrc'
    #
    # @example
    #   Rc = Optimism.require("~/.gutenrc")
    #
    #   Rc = Optimism.require("/absolute/path/rc.rb")
    #
    #   Rc = Optimism.require("guten/rc") #=> load 'APP/lib/guten/rc.rb'
    #   # first try 'guten/rc.rb', then 'guten/rc'
    #   
    # @param [String] name
    # @return [Optimism]
    def require(name)
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
          $:.each { |p|
            ['.rb', ''].each { |ext|
              file = File.join(p, name+ext)
              if File.exists? file
                path = file
                throw :break
              end
            }
          }
        end
      end

      raise LoadError, "can't find file -- #{name}" unless path

      Optimism.eval File.read(path)
    end
  end

  undef_method *BUILTIN_METHODS
  include Semantics
  include HashMethodFix

  # parent node, a <#Optimism>
  attr_accessor :_parent 

  # child node, a hash data
  attr_accessor :_child 

  # root node, a <#Optimism>
  attr_accessor :_root

  # @param [Object] (nil) default create a new hash with the defalut value
  def initialize(default=nil, options={}, &blk)
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

  # set data
  def []=(key, value)
    key = key.respond_to?(:to_sym) ? key.to_sym : key

    @_child[key] = value
  end

  # get data
  def [](key)
    key = key.respond_to?(:to_sym) ? key.to_sym : key

    @_child[key]
  end

  def ==(other)
    _child == other._child
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
        next_optimism = Optimism.new(nil, {_root: _root})
        next_optimism._parent = self
        self._child[name] = next_optimism
        next_optimism.instance_eval(&blk) if blk
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

end

module Kernel
  # a handy method 
  def Optimism(default=nil, &blk)
    Optimism.new default, &blk
  end
end
