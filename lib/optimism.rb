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

  # the node name, a Symbol
  attr_accessor :_name

  attr_accessor :_data 
  alias _d _data
  alias _children _data

  # initialize
  # 
  # @example
  #
  #   # with :default option
  #   rc = Optimism.new(nil, default: 1)
  #   rc.i.donot.exists #=> 1
  #
  #   # with :namespace option
  #   rc = Optimism.new("foo=1", :namespace => "a.b")
  #   rc.a.b.foo #=> 1
  #
  #   # root node
  #   Optimism.new()         # is {name: "", parent: nil}
  #
  #   # sub ndoe
  #   Optimism.new(nil, name: "b", parent: o) 
  #
  # @param [String,Hash,Optimism] content
  # @param [Hash] options
  # @option options [Object] :default (nil) default value for Hash
  # @option options [String] :namespace
  # @option options [Boolean] :symbolize_key (true)
  def initialize(content=nil, options={}, &blk)
    @options = {symbolize_key: true}.merge(options)
    @_parser = Parser.parsers[options[:parser] || :default]
    @_name = @options[:name] || ""
    @_parent = @options[:parent]

    case content
    when Hash
      @_data = _convert_hash(content, @options)._d
    when Optimism
      @_data = content._d
    else
      @_data = Hash.new(@options[:default])
      _parse! content, &blk if content or blk
    end

    _walk("-#{@options[:namespace]}", :build => true) if @options[:namespace]
  end

  # Returns true if equal without compare node name.
  #
  def ==(other)
    case other 
    when Optimism
      _data == other._d
    else
      false
    end
  end

  # deep merge new data IN PLACE
  #
  # @params [Hash,Optimism,String] other
  # @return [self]
  def _merge!(other)
    other = Optimism.new(other)
    
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
    o._data = _d.dup
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
    self._data = other._d

    self
  end

  ## path
  ##

  # parent node
  attr_accessor :_parent 

  # root node
  attr_reader :_root
  def _root
    node = self

    while node._parent
      node = node._parent
    end

    node
  end
  alias _r _root

  alias _children _data

  # current node
  attr_reader :_
  def _
    self
  end

  # walk along the path.
  #
  # @example 
  #
  #  _walk("_")    ->   self
  #
  #  o = Optimism(a: {b: {c: {d: 1}}})
  #  o._walk("a.b.c")               -> <#Optimism:c ..>
  #  o._walk("-b.a")                -> <#Optimism:a ..>
  #
  # @param [String] path
  # @param [Hash] options
  # @option options [Boolean] (false) :build build the path if path doesn't exists.
  # @return [Optimism,nil] the result node.
  def _walk(path, options={})
    return self if %w[_ -_].include?(path)

    path =~ /^-/ ? _walk_up(path[1..-1], options) : _walk_down(path, options)
  end

  # walk along the path. IN PLACE
  # @see _walk
  #
  # @return [Optimism] self
  def _walk!(path, options={})
    _replace _walk(path, options)
  end

  # support path
  #
  # @overload _has_key?(key)
  #   @param [String,Symbol] key
  # @overload _has_key?(path)
  #   @param [String] path
  #
  # @see Hash#has_key?
  def _has_key?(path)
    case path
    when Symbol
      base, key = "_", path
    else
      base, key = _split_path(path.to_s)
    end

    node = _walk(base)

    if node then
      return node._d.has_key?(_convert_key(key))
    else
      return false
    end
  end

  def [](key)
    _data[_convert_key(key)]
  end

  # set data
  #
  def []=(key, value)
    # link node if value is <#Optimism>
    if Optimism === value
      value._parent = self 
      value._name = key.to_sym
    end

    _data[_convert_key(key)] = value
  end

  # fetch with path support.
  #
  # @overload _fetch(path, [default])
  #
  # @example
  #
  #   o = Optimism do |c|
  #     c.a = 1
  #     c.b.c = 2
  #   end
  #
  #   o._fetch("not_exitts")      -> raise KeyError
  #   o._fetch("not_exitts", nil) -> nil
  #   o._fetch("b.c")             -> 2
  #   o._fetch("c.d", nil)        -> nil. path doesn't exist.
  #   o._fetch("a.b", nil)        -> nil. path is wrong
  #
  # @param [String] key
  # @return [Object] value
  # @see Hash#fetch
  def _fetch(*args)
    if args.length == 1 then
      path = args[0]
      raise_error = true
    else
      path, default = args
    end

    base, key = _split_path(path)
    node = _walk(base)

    if node & node._has_key?(key) then
      return node._fetch(key)
    else
      if raise_error then
        raise KeyError, "key not found -- #{path.inspect}"
      else
        return default
      end
    end
  end

  # store with path support.
  #
  # @exampe
  #
  #  o = Optimism.new
  #  o._store("a.b", 1)      -> 1
  #
  # @param [Hash] o
  # @return [Object] value
  def _store(path, value)
    path, key = _split_path(path)

    node = _walk(path, :build => true)
    node[key] = value

    value
  end

  def _parse!(content=nil, &blk)
    @_parser.parse(self, content, &blk)
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
    _d.each { |k,v|
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
    return super if [:to_ary].include?(name)

    # relative path: __
    if name =~ /^__+$/
      num = name.to_s.count("_") - 1
      node = self
      num.times {
        return unless node
        node = node._parent
      }
      return node

    # .name=
    elsif name =~ /(.*)=$/
      return _data[$1.to_sym] = args[0]

    # ._name
    elsif name =~ /^_(.*)/
      name = $1.to_sym
      args.map!{|arg| Optimism === arg ? arg._d : arg} 
      return _data.__send__(name, *args, &blk)

    # .name?
    elsif name =~ /(.*)\?$/
      return !! _data[$1.to_sym]

    ##
    ## a.c  # return data if has :c
    ## a.c  # create new <#Optimism> if no :c 
    ##

    # p Rc.a.b.c #=> 1
    # p Rc.a.b.c('bar') 
    #
    elsif _data.has_key?(name)
      value = _data[name]
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

  def respond_to_missing?(name, include_private=false)
    return super if [:to_ary].include?(name)
    true
  end

protected

    # deep convert Hash to optimism. 
    # I'm rescursive.
    # @protected
    # 
    # @overload convert_hash(hash) 
    #
    # @example
    #
    #   convert_hash({a: {b: 1})     -> {:a => <#Optimism :b => 1>}
    #
    # @param [Hash] hash
    # @option options [Hash] :symbolize_key (nil)
    # @return [Hash]
    def _convert_hash(hash, options={})
      o = Optimism.new(nil, options)

      hash.each { |k, v|
        v = _convert_hash(v, options.merge(name: k.to_s, parent: o)) if Hash === v
        k = (k.to_sym rescue k) || k if options[:symbolize_key]

        o._d[k] = v
      }

      o
    end

  # Deep destructively convert all keys to symbols, as long as they respond
  # to +to_sym+. Same as +symbolize_keys+, but modifies +self+.
  # I'm recursive.
  def _symbolize_keys!(hash)
    hash.keys.each do |key, value|
      value = hash.delete(key)
      _symbolize_keys!(value) if Hash === value

      hash[(key.to_sym rescue key) || key] = value
    end

    hash
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
  def _walk_up(path, options={})
    node = self
    nodes = path.split(".")
    nodes.each { |name|
      if node._parent and node._parent._name == name
          node = node._parent
      elsif !node._parent and options[:build]
        new_node = Optimism.new(nil, default: @options[:default])
        new_node[name.to_sym] = node # link the node.
        node = new_node
      else
        return nil
      end
    }
    node
  end

  # @see _walk
  def _walk_down!(path, options={})
    _replace _walk_down(path, options)
  end

  # @see _walk
  def _walk_up!(path, options={})
    _replace _walk_up(path, options)
  end

  # split a path into path and key.
  #
  # "foo.bar.baz" => ["foo.bar", "baz"]
  # "foo" => [ "_", "foo"]
  #
  # @return [Array<string>] [base_path, key]
  def _split_path(path)
    paths = path.split('.')

    if paths.size == 1
      ["_", paths[0]]
    else
      [paths[0..-2].join('.'), paths[-1]]
    end
  end
end

module Kernel
  # a short-cut to Optimism.new
  def Optimism(*args, &blk)
    Optimism.new(*args, &blk)
  end
end

require "optimism/parser"
