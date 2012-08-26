require "optimism/util"
require "optimism/parser"
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

  Error         = Class.new Exception 
  EMissingFile   = Class.new Error
  EPath         = Class.new Error
  EParse        = Class.new Error

  BUILTIN_METHODS = [:p, :sleep, :rand, :srand, :exit, :require, :at_exit, :autoload, :open, :send] # not :raise
  UNDEF_METHODS = [:to_ary, :&, :_root=, :_=, :_replace]

  @@extension = {}
  class << self
    public *BUILTIN_METHODS 
    public :undef_method

    # Return all extensions for require.
    def extension
      @@extension
    end

    # Add an extension for require.
    #
    # @example
    #
    #   add_extension(".rb", Optimism::Parser::Default)
    #   Optimism.require("a.rb")   # will use Default Parser to parse the content.
    #
    # @param [String, Array]
    # @param [Class] parser
    def add_extension(extension_s, parser)
      extensions = Util.wrap_array(extension_s)

      extensions.each { |ext|
        @@extension[ext] = parser
      }
    end
  end

  include Require

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
  #   rc               -> <#Optimism foo: 1>
  #   rc._root         -> <#Optimism a: <#Optimsm b: <#Optimism foo: 1>>>
  #
  #   # root node
  #   Optimism.new()         # is {name: "", parent: nil}
  #
  #   # sub node
  #   Optimism.new(nil, name: "b", parent: o) 
  #
  #   # link sub node
  #   a = Optimism.new()
  #   b = Optimism.new()
  #   a[:foo] = b            # set b._name and b._parent
  #
  # @param [String,Hash,Optimism] content
  # @param [Hash] opts
  # @option opts [Object] :default (nil) default value for Hash
  # @option opts [Boolean] :symbolize_key (true)
  # @option opts [String] :namespace (nil)
  # @option opts [String] :name ("") node name
  # @option opts [Optimism] :parent (nil) parent node
  # @option opts [Symbol,Class,Proc] :parser (:default) parser to parse content and block. 
  def initialize(content=nil, opts={}, &blk)
    @opts = {symbolize_key: true}.merge(opts)

    @_parser = case (p=opts[:parser])
               when Symbol
                Parser.parsers[p].method(:parse)
               when Class
                 p.method(:parse)
               when Proc
                 p
               else
                 Parser::Default.method(:parse)
               end

    @_name = @opts[:name] || ""
    @_parent = @opts[:parent]

    case content
    when Hash
      @_data = _convert_hash(content, @opts)._d
    when Optimism
      @_data = content._d
    else
      @_data = Hash.new(@opts[:default])
      _parse! content, &blk if content or blk
    end

    _walk_up(@opts[:namespace], :build => true, :reverse => true) if @opts[:namespace]
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
    other = Optimism.new(other, Util.slice(@opts, :default, :symbolize_key, :parser))
    
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

  # shadow Duplicate
  #
  # @exmaple
  # 
  #  a = Optimism({a: {b: {c: 1}}})
  #  b = a._walk_down("a")
  #
  #  b2 = b._dup
  #  b2._parent = parent_node
  #
  #  b  -> {c: 1}
  #  b2 -> {c: 1}
  #
  # @return [Optimism] new <#Optimism>
  def _dup
    o = Optimism.new(nil, @opts)
    o._data = _d.dup
    o._data.each {|k,v| v.instance_variable_set(:@_parent, o) if Optimism === v}

    o
  end

  ## path
  ##

  # parent node
  attr_accessor :_parent 
  def _parent=(parent)
    @_parent = parent

    if parent
      parent._d[_name.to_sym] = self
    end
  end

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
  # @param [Hash] opts
  # @option opts [Boolean] :build (nil) build the path if path doesn't exists.
  # @option opts [Boolean] :reverse (nil) reverse the path
  # @return [Optimism,nil] the result node
  def _walk(path, opts={})
    return self if %w[_ -_].include?(path)

    path =~ /^-/ ? _walk_up(path[1..-1], opts) : _walk_down(path, opts)
  end

  # @see _walk
  def _walk_down(path, opts={})
    node = self
    nodes = path.split(".")
    nodes.reverse! if opts[:reverse]

    nodes.each { |name|
      name = name.to_sym
      if node._has_key?(name) and Optimism === node[name]
        node = node[name]
      elsif !node._has_key?(name) and opts[:build]
        node = node._create_child_node(name)
      else
        return nil
      end
    }

    node
  end

  # @see _walk
  #
  def _walk_up(path, opts={})
    node = self
    nodes = path.split(".")
    nodes.reverse! if opts[:reverse]

    nodes.each { |name|
      if node._parent and node._parent._name == name
          node = node._parent
      elsif !node._parent and opts[:build]
        node = node._create_parent_node(name)
      else
        return nil
      end
    }
    node
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
      value.instance_variable_set(:@_parent, self)
      value._name = key.to_sym
    end

    _data[_convert_key(key)] = value
  end

  # fetch with path support.
  #
  # @overload _fetch(key, [default])
  #   @param [String, Symbol] key
  # @overload _fetch(path, [default])
  #   @param [String] path
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

    case path
    when Symbol
      base, key = "_", path
    else
      base, key = _split_path(path.to_s)
    end

    node = _walk(base)

    if node && node._has_key?(key) then
      return node[key]
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
  # @overload _store(key, value)
  #   @param [Symbol, String] key
  # @overload _store(path, value)
  #   @param [String] path
  #
  # @exampe
  #
  #  o = Optimism.new
  #  o._store("a.b", 1)      -> 1
  #
  # @param [Hash] o
  # @return [Object] value
  def _store(path, value)
    case path
    when Symbol
      base, key = "_", path
    else
      base, key = _split_path(path.to_s)
    end

    node = _walk(base, :build => true)
    node[key] = value

    value
  end

  # Delete an item.
  #
  # @overload _delete(key)
  #   @param [String, Symbol] key
  # @overload _delete(path)
  #   @param [String] path
  #
  def _delete(path, &blk)
    case path
    when Symbol
      base, key = "_", path
    else
      base, key = _split_path(path.to_s)
    end

    node = _walk(base)

    if node
      node._d.delete(_convert_key(key), &blk)
    else
      blk ? blk.call : nil
    end
  end

  def _parse!(content, &blk)
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
    _d.each { |k,v|
      rst << "#{indent}#{k.inspect} => "
      rst << (Optimism === v ? "#{v.inspect(indent+"  ")}\n" : "#{v.inspect}\n")
    }
    rst.rstrip! << ">"

    rst
  end

  alias to_s inspect
  alias to_str to_s

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
    return super if UNDEF_METHODS.include?(name)

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
      return _create_child_node(name, args[0], &blk)
    end
  end

  def respond_to_missing?(name, include_private=false)
    return super if UNDEF_METHODS.include?(name)
    true
  end

  # Create a new child node, link it and return it.
  # @protected
  #
  def _create_child_node(name, content=nil, opts={}, &blk)
    options = Util.slice(@opts, :default, :symbolize_key, :parser).merge(opts).merge({name: name.to_s, parent: self})
    next_node = Optimism.new(content, options, &blk)
    _data[name.to_sym] = next_node

    next_node
  end

  # Create a new parent node, link it  and return it.
  # @protected
  def _create_parent_node(child_name, content=nil, opts={}, &blk)
    options = Util.slice(@opts, :default, :symbolize_key, :parser).merge(opts)
    prev_node = Optimism.new(content, options, &blk)
    self._name = child_name.to_s
    self._parent = prev_node
    prev_node._data[child_name.to_sym] = self

    prev_node
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
  # @option opts [Hash] :symbolize_key (nil)
  # @return [Hash]
  def _convert_hash(hash, opts={})
    o = Optimism.new(nil, opts)

    hash.each { |k, v|
      v = _convert_hash(v, opts.merge(name: k.to_s, parent: o)) if Hash === v
      k = (k.to_sym rescue k) || k if opts[:symbolize_key]

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
    if @opts[:symbolize_key] and String === key
      key.to_sym 
    else
      key
    end
  end

  # split a path into path and key.
  #
  # "foo.bar.baz" => ["foo.bar", "baz"]
  # "foo" => [ "_", "foo"]
  #
  # @return [Array<string>] [base_path, key]
  def _split_path(path, opts={})
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

# extensions
require "optimism/parser/default"
require "optimism/parser/yaml"
require "optimism/parser/json"
