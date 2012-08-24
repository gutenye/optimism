module Optimism::Parser
  class Default < Base
    class Filter
      attr_accessor :content

      # input any thing
      def initilaize(content)
        raise NotImplementedError, ""
      end

      # => any thing
      def evaluate
        raise NotImplementedError, ""
      end

    end

    # convert sugar syntax
    #
    #   develoment:
    #     database 'postgresql'
    #
    # to a pure ruby syntax
    #
    #   development do
    #     database 'postgresql'
    #   end
    #
    class StringBlock2RubyBlock < Filter
      INDENT="  "

      # the string data.
      attr_reader :content

      def initialize(content)
        @content = content
      end

      # compile sugar-syntax into ruby-syntax
      def evaluate
        script = ""
        indent_counts = 0
        block_indent_counts = []
        block_index = 0

        scan(content) { |token, statement|
          case token
          when :block_start
            block_indent_counts << indent_counts
            statement = statement.sub(/\s*:/, " <<-OPTIMISM_EOF#{block_index}" )
            block_index += 1
            script << statement << "\n"
          when :statement
            script << statement << "\n"
          when :indent
            indent_counts += 1
            script << INDENT*indent_counts
          when :undent
            script << INDENT*indent_counts
          when :dedent
            indent_counts -= 1
            if indent_counts == block_indent_counts[-1]
              block_index -= 1
              script << INDENT*(indent_counts) + "OPTIMISM_EOF#{block_index}\n"
              block_indent_counts.pop
            else
              script << INDENT*(indent_counts)
            end
          end
        }

        script
      end

    private
      def scan(content, &blk)
        return to_enum(:scan, content) unless blk
        last_indent = 0

        content.scan(/(.*?)(\n+|\Z)/).each { |line, newline|
          _, indents, statement = line.match(/^(\s*)(.*)/).to_a

          # indent
          # a:
          #   b 1
          #   c:
          #     d 1
          #     e:
          #       f 1
          #   g 1
          indent = 
            if indents == ""
              0
            elsif indents =~ /^ +$/
            (indents.count(" ") / INDENT.length.to_f).ceil
            elsif indents =~ /^\t+$/
              indents.count("\t")
            else
              raise Error, "indent error -- #{indents.inspect}"
            end
          counts = indent - last_indent
          last_indent = indent

          if counts == 0
            blk.call :undent
          else
            counts.abs.times {
              blk.call counts>0 ? :indent : :dedent
            }
          end

          # statement
          if statement =~ /:\s*$/
            blk.call :block_start, statement.gsub(/\s*:\s*$/, ':')
          else
            blk.call :statement, statement
          end
        }
      end
    end

    #
    #   foo = _.name
    # =>
    #   foo = lambda { _.name }
    # 
    # all posibilities
    #
    #   foo = _.name
    #   foo = ___.name
    #   foo = true && _foo || _.bar
    #
    class Path2Lambda < Filter
      def initialize(content)
        @content = content
      end

      def evaluate
        content.split("\n").each.with_object("") { |line, memo|
          line.split(";").each { |stmt|
            memo << stmt.gsub(/_+\.[a-z_][A-Za-z0-9_]*/){|m| " lambda { #{m} }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)} "}.rstrip
            memo << "\n"
          }
        }
      end
    end

    #
    #   a <<-OPTIMISM_EOF0
    #     name = 2
    #     b <<-OPTIMISM_EOF1
    #       age = 1
    #     OPTIMISM_EOF1
    #   OPTIIMMS_EOF0
    #
    # ->
    #
    #  [:name]
    class CollectLocalVariables < Filter
      LOCAL_VARIABLE_PAT=/(.*?)([a-zA-Z_.][a-zA-Z0-9_]*)\s*=[^~=]/

      # @return [Array] local_variable_names
      def initialize(content)
        @content = content
      end

      def evaluate
        content = remove_block_string(@content)
        content.scan(LOCAL_VARIABLE_PAT).each.with_object([]) { |match, memo|
          name = match[1]
          next if name=~/^[A-Z.]/ # constant and method
          memo << name.to_sym
        }
      end

    private

      # @example
      #   c = 1
      #   a <<-OPTIMISM_EOF
      #    b = 2
      #   OPTIMISM_EOF
      # #=>
      #   c = 1
      def remove_block_string(content)
        content.gsub(/
          (?<brace>
           (\A|\n)[^\n]+<<-OPTIMISM_EOF[0-9]+
             (
                 (?!<<-OPTIMISM_EOF|OPTIMISM_EOF). 
               |
                 \g<brace>
             )*
           OPTIMISM_EOF[0-9]+
          )/mx, '')
      end
    end

    def self.parse(optimism, content, &blk)
      new(optimism).parse!(content, &blk)
    end

    def initialize(optimism)
      @optimism = optimism
    end

    def parse!(content=nil, &blk)
      if content
        eval_string(content)
      elsif blk
        eval_block(&blk)
      end
    end

    private

    # Eval a block
    #
    # @example
    #
    #   eval_block do |o|
    #     o.pi = 3.14
    #   end
    #
    def eval_block(&blk)
      @optimism.__send__ :instance_exec, @optimism, &blk
    end

    # Eval string
    #
    # @example
    #
    #   eval_string <<-EOF
    #     a = 1
    #     b:
    #       c = 2
    #   EOF
    #
    def eval_string(content)
      content = Parser::StringBlock2RubyBlock.new(content).evaluate 
      content = Parser::Path2Lambda.new(content).evaluate

      collect_variables(content)

      call_lambda_path(@optimism)
    end

    # Collect variables from content.
    #
    # @example
    #
    #   collect_variables <<-EOF
    #    a = 1
    #    b <<-OPTIMISM_EOF0
    #      c = 2
    #    OPTIMISM_EOF0
    #   EOF
    #
    #   -> {a: 1}
    #
    #
    # @param [String] content
    # @return nil
    def collect_variables(content)
      vars = Parser::CollectLocalVariables.new(content).evaluate

      begin
        bind = @optimism.instance_eval do
          bind = binding
          eval content, bind
          bind
        end
      rescue SyntaxError => e
        raise EParse, "parse config file error.\n CONTENT:  #{content}\n ERROR-MESSAGE: #{e.message}"
        exit
      end

      vars.each { |name|
        value = bind.eval(name.to_s)
        @optimism[name] = value
      }

      nil
    end

    # Call the lambda-path.
    # I'm rescurive
    #
    #  rc = Optimism <<EOF
    #    a = _.foo  -> a = lambda{ _.foo }.tap{|s| s.instance_variable_set(:@_is_optimism_path, true)
    #  EOF
    #  ->
    #    a = 1
    def call_lambda_path(optimism)
      data = optimism._d

      data.each { |k,v|
        if Proc === v and v.lambda? and v.instance_variable_get(:@_is_optimism_path)
          data[k] = v.call
        elsif Optimism === v
          call_lambda_path(v)
        end
      }
    end
  end
end
