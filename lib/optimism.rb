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
#
# internal, string-key is converted into symbol-key
#
#  Rc = Optimism.new
#  Rc[:a] = 1
#  Rc["a"] = 2
#  p Rc[:a] #=> 2
#
# if you want disable it. with :only_symbol_key => ture in constructor function.
#
#
class Optimism
  autoload :VERSION, "optimism/version"

  Error         = Class.new Exception 
  MissingFile   = Class.new Error
  EPath     = Class.new Error
  EParse        = Class.new Error

  BUILTIN_METHODS = [:p, :sleep, :rand, :srand, :exit, :require, :at_exit, :autoload, :open, :send] # not :raise

  class << self
    public *BUILTIN_METHODS 
    public :undef_method

    include Require

    # get Hash data from any Hash or Optimism
    #
    # @param [Optimism, Hash] obj
    # @return [Hash] 
    def get(obj)
      case obj
      when Hash
        obj
      when Optimism
        obj._child
      else
        raise ArgumentError, "wrong argument -- #{obj.inspect}"
      end
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
        o = Optimism.new(:default => data.default)
        o._child = data
        o
      else
        raise ArgumentError, "wrong argument -- #{data.inspect}"
      end
    end

    # deep convert Hash to optimism
    # 
    # @example
    #   convert({a: {b: 1})
    #   #=> Optimism[a: Optimism[b: 1]]
    #
    # @param [Hash,Optimism] hash
    # @return [Optimism]
    def convert(hash, options={})
      case hash
      when Optimism
        hash
      when Hash
        node = Optimism.new(:default => hash.default)
        hash.each { |k,v|
          node[k] = Hash===v ? convert(v, :name => k) : v
        }
        node
      else
        raise ArgumentError, "wrong argument -- #{hash.inspect}"
      end
    end
  end

  undef_method *BUILTIN_METHODS
  include Semantics
  include HashMethodFix
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

  # child node, a hash data
  attr_accessor :_child 
  alias _data _child
  alias _data= _child=

  # initialize
  # 
  # @example
  #
  #  # with :default option
  #  rc = Optimism.new(:default => 1)
  #  rc.i.donot.exists #=> 1
  #
  #  # with :namespace option
  #  rc = Optimism.new("foo=1", :namespace => "a.b")
  #  rc.a.b.foo #=> 1
  #
  # @overload initialize(content=nil, options={}, &blk)
  #   @param [String] content
  # @overload initialize(options={}, &blk)
  #   @param [Hash] options
  #   @option options [Object] :default (nil) default value for Hash
  #   @option options [String] :namespace
  #   @option options [Boolean] :only_symbol_key (nil)
  def initialize(*args, &blk)
    raise ArgumentError, "wong argument -- #{args.inspect}" if args.size > 2
    case v=args.pop
    when Hash
      @options = v
      content = args[0]
    else 
      @options = {}
      content = v
    end

    @_name = @options[:name] || :_ # root name
    @_root = self # first time is self.
    @_parent = nil
    @_child = Hash.new(@options[:default])

    _walk("-#{@options[:namespace]}", :build => true) if @options[:namespace]

    _eval(content, &blk) if content or blk

    _root
  end

  # walk along the path.
  #
  # @param [String] path 'a.b' '-a.b'
  # @param [Hash] options
  # @option options [Boolean] (false) :build build the path if path doesn't exists.
  # @return [Optimism] the result node.
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

  # support path
  def _has_key2?(path)
    path, key = _split(path)

    begin
      node = _walk(path)
    rescue EPath
      false
    else
      node._has_key?(key)
    end
  end

  def [](key)
    key = key.to_sym if String===key and !@options[:only_symbol_key]

    @_child[key]
  end

  # set data
  #
  def []=(key, value)
    # link node if value is <#Optimism>
    if Optimism === value
      value._parent = self 
      value._name = key.to_sym
    end

    if String===key and !@options[:only_symbol_key]
      key = key.to_sym
    end

    @_child[key] = value
  end

  # support path
  def _fetch2(path, default=nil)
    path, key = _split(path)

    node = _walk(path, :build => true)

    if node._has_key?(key)
      node[key]
    else
      node[key] = default
    end
  end

  # _store2 like _store, but support a path.
  # @see _walk
  #
  # @exampe
  #
  #  o = Optimism.new
  #  o._store2('a.b', 1) #=> 1, the value of a.b
  #
  # @param [Hash] o
  # @option o [String] :namespace => path
  # @option o [Boolean] (true) :build
  # @return [Object] value
  def _store2(path, value, o={})
    o = {:build => true}.merge(o)
    path, key = _split(path)

    if path =~ /^-/
      tmp_node = _walk(path, :build => o[:build])
      tmp_node._walk(o[:namespace], :build => true)
      node = self
    else
      node = _walk(o[:namespace], :build => true)
      node = node._walk(path, :build => o[:build])
    end
    node[key] = value

    value
  end

  # equal if same _child. not check _parent or _root.
  #
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
    o = Optimism.new(@options)
    o._name = self._name
    o._child = _child.dup
    o._child.each {|k,v| v._parent = o if Optimism===v}

    o
  end

  # replace with a new <#Optimism>
  #
  # @param [Optimism] obj
  # @return [Optimism] self
  def _replace(other)
    new_node = _dup
    self._parent[self._name] = new_node if self._parent # link

    self._parent = other._parent
    self._name = other._name
    self._child = other._child

    self
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
      return @_child.__send__(name, *args, &blk)

    # .name?
    elsif name =~ /(.*)\?$/
      return !! @_child[$1.to_sym]

    ##
    ## a.c  # return data if has :c
    ## a.c  # create new <#Optimism> if no :c 
    ##

    # p Rc.a.b.c #=> 1
    # p Rc.a.b.c('bar') 
    #
    elsif @_child.has_key?(name)
      value = @_child[name]
      return (Proc===value && value.lambda?) ? value.call(*args) : value

    # p Rc.a.b.c #=> create new <#Optimism>
    #
    # a.b do |c|
    #   c.a = 2
    # end
    #
    # a.b <<-EOF 
    #   a = 2
    # EOF
    #
    else
      next_o = Optimism.new(:default => @options[:default])
      self[name] = next_o # link the node
      content = args[0]
      next_o.__send__ :_eval_contained_block, content, &blk if content or blk
      return next_o
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
    rst << "<#Optimism:#{_name}\n"
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

  # @option options [Boolean] :contained
  def _eval(content=nil, &blk)
    if content
      content = Parser::StringBlock2RubyBlock.new(content).evaluate 
      content = Parser::Path2Lambda.new(content).evaluate
      _eval_string content

      _fix_lambda_values
    elsif blk
      _eval_block(&blk)
    end

  end

  def _eval_contained_block(content=nil, &blk)
    content ? _eval_string(content) : _eval_block(&blk)
  end

  def _eval_block(&blk)
    meth = _blk2method(&blk)
    blk.arity == 0 ?  meth.call : meth.call(self)
  end

  # parse the string content
  #
  # @param [String] content
  # @return nil
  def _eval_string(content)
    bind = binding

    vars = Parser::CollectLocalVariables.new(content).evaluate

    begin
      eval content, bind
    rescue SyntaxError => e
      raise EParse, "parse config file error.\n CONTENT:  #{content}\n ERROR-MESSAGE: #{e.message}"
      exit
    end

    vars.each { |name|
      value = bind.eval(name)
      @_child[name.to_sym] = value
    }

    nil
  end

  # I'm rescurive
  #
  # for 
  #
  #  rc = Optimism <<-EOF
  #    a = _.foo
  #  EOF
  #
  # =>
  #
  #  a = lambda{ _.foo }.tap{|s| s.instance_variable_set(:@_optimism, true)
  #
  def _fix_lambda_values
    @_child.each { |k,v|
      if Proc===v and v.lambda? and v.instance_variable_get(:@_optimism)
        @_child[k] = v.call
      elsif Optimism===v
        v.__send__ :_fix_lambda_values
      end
    }
  end

  # @see _walk
  def _walk_down(path, options={})
    node = self
    nodes = path.split(".")
    nodes.each { |name|
      name = name.to_sym
      if node._has_key?(name)
        case node[name]
        when Optimism
          node = node[name]
        else 
          raise EPath, "wrong path: has a value along the path -- name(#{name}) value(#{node[name].inspect})" 
        end
      else
        if options[:build]
          new_node = Optimism.new(:default => @options[:default])
          node[name] = new_node # link the node.
          node = new_node
        else
          raise EPath, "path not exists. -- path: `#{path}'. cur-name: `#{name}'"
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
          raise EPath, "wrong path: parent node doen't exists -- parent-name(#{node._parent._name}) current-name(#{name})"
        end
      else
        if options[:build]
          new_node = Optimism.new(:default => @options[:default])
          new_node[name] = node # lnk the node.
          node = new_node
        else
          raise EPath, "path doesn't exist. -- path: `#{path}'. cur-name: `#{name}'"
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

  # "foo.bar.baz" => ["foo.bar", :baz]
  # "foo" => [ "", :foo]
  def _split(path)
    paths = path.split('.')
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
  # a handy method 
  def Optimism(*args, &blk)
    Optimism.new *args, &blk
  end
end
