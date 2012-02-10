class Optimism
  module Parser
    class Base
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
    class StringBlock2RubyBlock < Base
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
    class Path2Lambda < Base
      def initialize(content)
        @content = content
      end

      def evaluate
        content.split("\n").each.with_object("") { |line, memo|
          line.split(";").each { |stmt|
            memo << stmt.gsub(/_+\.[a-z_][A-Za-z0-9_]*/){|m| " lambda { #{m} }.tap{|s| s.instance_variable_set(:@_optimism, true)} "}.rstrip
            memo << "\n"
          }
        }
      end
    end

    class CollectLocalVariables < Base
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
          memo << name
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
  end
end

