require "optimism/semantics"
require "optimism/require"

#
# <#Optimism> is a node, it has _data, _parent and _root attribute.
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
#  Rc.a._data #=> {:b => 1, :c => <#Optimism>}
#  Rc.a._parent #=> is Rc
#  Rc.a._root #=> is Rc
#
#  Rc._parent #=>  nil
#  Rc._root #=> is Rc
#
# internal, string-key is converted into symbol-key
#
#  Rc = Optimism.new
#  Rc[:a] = 1
#  Rc["a"] = 2
#  p Rc[:a] #=> 2
#
# if you want disable it. with :symbolize_key => ture in constructor function.
class Optimism
  autoload :VERSION, "optimism/version"
  autoload :Util, "optimism/util"

  Error         = Class.new Exception 
  MissingFile   = Class.new Error
  EPath         = Class.new Error
  EParse        = Class.new Error

  BUILTIN_METHODS = [:p, :sleep, :rand, :srand, :exit, :require, :at_exit, :autoload, :open, :send] # not :raise

  class << self
    public *BUILTIN_METHODS 
    public :undef_method
  end

  extend Require

  undef_method *BUILTIN_METHODS
  include Semantics
  include RequireInstanceMethod

  # the node name, a Symbol
  attr_accessor :_name

  # parent node, a <#Optimism>
  attr_accessor :_parent 

  # root node, a <#Optimism>
  attr_reader :_root
  def _root
    parent = self
    while parent._parent
      parent = parent._parent
    end

    parent
  end

  attr_accessor :_data 

  # initialize
  # 
  # @example
  #
  #  # with :default option
  #  rc = Optimism.new(nil, default: 1)
  #  rc.i.donot.exists #=> 1
  #
  #  # with :namespace option
  #  rc = Optimism.new("foo=1", :namespace => "a.b")
  #  rc.a.b.foo #=> 1
  #
  # @param [String,Hash,Optimism] content
  # @param [Hash] options
  # @option options [Object] :default (nil) default value for Hash
  # @option options [String] :namespace
  # @option options [Boolean] :symbolize_key (true)
  def initialize(content=nil, options={}, &blk)
    @options = {symbolize_key: true}.merge(options)
    @_parser = @options[:parser] || Optimism.parser
    # first time value.
    @_name = @options[:name] || :_  
    @_root = self
    @_parent = nil

    case content
    # for first time.
    when Hash
      @_data = _convert_hash(content)._data
    # for first time.
    when Optimsm
      @_data = content._data
    else
      @_data = Hash.new(@options[:default])
      _parse! content, &blk if content or blk
    end

    _walk("-#{@options[:namespace]}", :build => true) if @options[:namespace]
  end

  # Returns true if same _data.
  #
  def ==(other)
    case other 
    when Optimism
      _data == other._data
    else
      false
    end
  end

  # deep merge new data IN PLACE
  #
  # @params [Hash,Optimism,String] other
  # @return [self]
  def _merge!(other)
    other = case other
    when String
      Optimism.new(other)
    else
      Optimism.convert(other)
    end
    
    other._each { |k, v|
      if Optimism === self[k] and Optimism === other[k] 
        self[k]._merge!(other[k])
      else
        self[k] = other[k]
      end
    }

    self
  end

  alias << _merge!

  # deep merge new data
  #
  # @params [Hash,Optimism] obj
  # @return [Optimism] new <#Optimism>
  def _merge(other)
    self._dup._merge!(other)
  end

  alias + _merge

  # duplicate
  #
  # @return [Optimism] new <#Optimism>
  def _dup
    o = Optimism.new(@options)
    o._name = self._name
    o._data = _data.dup
    o._data.each {|k,v| v._parent = o if Optimism===v}

    o
  end

  # replace with a new <#Optimism>
  #
  # @param [Optimism] obj
  # @return [Optimism] self
  def _replace(other)
    # link
    if self._parent then
      self._parent[self._name] = _dup
    end

    self._parent = other._parent
    self._name = other._name
    self._data = other._data

    self
  end

  # walk along the path.
  #
  # @param [String] path 'a.b' '-a.b'
  # @param [Hash] options
  # @option options [Boolean] (false) :build build the path if path doesn't exists.
  # @return [Optimism,nil] the result node.
  def _walk(path, options={})
    return self unless path
    ret = path =~ /^-/ ? _walk_up(path[1..-1], options) : _walk_down(path, options)
    ret
  end

  # walk along the path. IN PLACE
  # @see _walk
  #
  # @return [Optimism] changed-self
  def _walk!(path, options={})
    path =~ /^-/ ? _walk_up!(path[1..-1], options) : _walk_down!(path, options)
  end

  def _has_key?(key)
    _data.has_key?(_convert_key(key))
  end

  # support path
  def _has_key2?(path)
    path, key = _split_path(path)

    node = _walk(path)

    if node then
      return node._has_key?(key)
    else
      return false
    end
  end

  def [](key)
    @_data[_convert_key(key)]
  end

  # set data
  #
  def []=(key, value)
    # link node if value is <#Optimism>
    if Optimism === value
      value._parent = self 
      value._name = key.to_sym
    end

    @_data[_convert_key(key)] = value
  end

  # fetch with path support.
  #
  # @example
  #
  #   o = Optimism do |c|
  #     c.a = 1
  #     c.b.c = 2
  #   end
  #
  #   o._fetch2("not_exitts") -> nil
  #   o._fetch2("b.c")        -> 2
  #   o._fetch2("c.d")        -> nil. path doesn't exist.
  #   o._fetch2("a.b")        -> nil. path is wrong
  #
  # @param [String] key
  # @return [Object] value
  def _fetch2(path, default=nil)
    path, key = _split_path(path)

    node = _walk(path)

    if node & node._has_key?(k) then
      return node[k]
    else
      return default
    end
  end

  # store with path support.
  #
  # @exampe
  #
  #  o = Optimism.new
  #  o._store2('a.b', 1) #=> 1, the value of a.b
  #
  # @param [Hash] o
  # @return [Object] value
  def _store2(path, value)
    path, key = _split_path(path)

    node = _walk(path, :build => true)
    node[key] = value

    value
  end

  def _parse!(content=nil, &blk)
    @_parser.call(self, content, &blk)
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
    rst << "<#Optimism:#{_name}\n"
    _data.each { |k,v|
      rst << "#{indent}#{k.inspect} => "
      rst << (Optimism === v ? "#{v.inspect(indent+"  ")}\n" : "#{v.inspect}\n")
    }
    rst.rstrip! << ">"

    rst
  end

  alias to_s inspect

  def to_hash
    _data
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
      return @_data[$1.to_sym] = args[0]

    # ._name
    elsif name =~ /^_(.*)/
      name = $1.to_sym
      args.map!{|arg| Optimism===arg ? arg._data : arg} 
      return @_data.__send__(name, *args, &blk)

    # .name?
    elsif name =~ /(.*)\?$/
      return !! @_data[$1.to_sym]

    ##
    ## a.c  # return data if has :c
    ## a.c  # create new <#Optimism> if no :c 
    ##

    # p Rc.a.b.c #=> 1
    # p Rc.a.b.c('bar') 
    #
    elsif @_data.has_key?(name)
      value = @_data[name]
      return (Proc === value && value.lambda?) ? value.call(*args) : value

    # p Rc.a.b.c #=> create new <#Optimism>
    #
    # a.b do |c|
    #   c.a = 2
    # end
    #
    # a.b <<EOF
    #   a = 2
    # EOF
    else
      next_o = Optimism.new(nil, default: @options[:default])
      self[name] = next_o # link the node
      content = args[0]
      next_o._parse! content, &blk
      return next_o
    end
  end

private
  # deep convert Hash to optimism. 
  # I'm rescursive.
  # 
  # @overload _convert_hash(hash) 
  #
  # @example
  #
  #   _convert_hash({a: {b: 1})     -> {:a => <#Optimism :b => 1>}
  #
  # @param [Hash] hash
  # @return [Optimism]
  def _convert_hash(hash, options={})
    node = Optimism.new(nil, {default: node.default}.merge(options))

    hash.each { |k,v|
      node[k] = Hash === v ? _convert_hash(v, name: k) : v
    }

    node
  end

  def _convert_key(key)
    if @options[:symbolize_key] and String === key
      key.to_sym 
    else
      key
    end
  end

  # @see _walk
  def _walk_down(path, options={})
    node = self
    nodes = path.split(".")
    nodes.each { |name|
      name = name.to_sym
      if node._has_key?(name)
        if Optimism === node[name]
          node = node[name]
        else 
          return nil
        end
      else
        if options[:build]
          new_node = Optimism.new(nil, default: @options[:default])
          node[name] = new_node # link the node.
          node = new_node
        else
          return nil
        end
      end

    }
    node
  end

  # @see _walk
  #
  # path: '_.a', _ is root
  #
  def _walk_up(path, options={})
    node = self
    nodes = path.split(".").reverse
    nodes.each { |name|
      name = name.to_sym
      if node._parent 
        if node._parent._name == name.to_sym
          node = node._parent
        else
          return nil
        end
      else
        if options[:build]
          new_node = Optimism.new(nil, default: @options[:default])
          new_node[name] = node # lnk the node.
          node = new_node
        else
          return nil
        end
      end
    }
    node
  end

  # @see _walk
  def _walk_down!(path, options={})
    node = _walk_down(path, options)
    _replace node
  end

  # @see _walk
  def _walk_up!(path, options={})
    node = _walk_up(path, options)
    _replace node
  end

  # split a path into path and key.
  #
  # "foo.bar.baz" => ["foo.bar", :baz]
  # "foo" => [ "", :foo]
  #
  # @return [Array] [path, key]
  def _split_path(fullpath)
    paths = fullpath.split('.')
    if paths.size == 1
      path = ""
      key = paths[0].to_sym
    else
      path = paths[0...-1].join('.')
      key = paths[-1].to_sym
    end

    [ path, key ]
  end
end

module Kernel
  # a short-cut to Optimism.new
  def Optimism(*args, &blk)
    Optimism.new(*args, &blk)
  end
end

require "optimism/parser"
require "optimism/yaml"
