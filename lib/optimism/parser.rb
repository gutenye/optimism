class Optimism
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
  class Parser

    LOCAL_VARIABLE_PAT=/(.*?)([a-zA-Z_.][a-zA-Z0-9_]*)\s*=[^~=]/
    INDENT="  "

    # the string data.
    attr_reader :content

    class << self
      # a handy method for Parser.new(content).compile
      def compile(content)
        parser = Parser.new(content)

        parser.compile
      end

      # @return [Array] local_variable_names
      def collect_local_variables(content)
        content = remove_block_string(content)
        content.scan(LOCAL_VARIABLE_PAT).each.with_object([]) { |match, memo|
          name = match[1]
          next if name=~/^[A-Z.]/ # constant and method
          memo << name
        }
      end

      # @example
      #   c = 1
      #
      #   a:
      #    b = 2
      #   c:
      #    d = 2
      #
      # #=>
      #   c = 1
      #
      # it removes 'a:' and 'c:' block
      def remove_block_string(content)
        block_start = false

        content.split("\n").each.with_object("") { |line, memo|
          if line=~/:\s*$/
            block_start = true
          elsif line=~/^[^\s]/
            block_start = false
          end

          if block_start == false
            memo << line + "\n"
          end
        }
      end
    end

    def initialize content
      @content = content
    end

    # compile sugar-syntax into ruby-syntax
    def compile
      script = ""
      indent_counts = 0
      block_start = false

      scan { |token, statement|
        case token
        when :block_start
          block_start = true
          statement = statement.sub(/\s*:/, "._eval <<-EOF")
          script << statement << "\n"
        when :statement
          script << statement << "\n"
        when :indent
          indent_counts += 1
          script << INDENT*indent_counts
        when :undent
          script << INDENT*indent_counts
        when :dedent
          if block_start
            block_start = false
            script << INDENT*(indent_counts-1) + "EOF\n"
          else
            script << INDENT*(indent_counts-1)
          end
          indent_counts -= 1
        end
      }

      script
    end

  private
    def scan
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
          yield :undent
        else
          counts.abs.times {
            yield counts>0 ? :indent : :dedent
          }
        end

        # statement
        if statement =~ /:\s*$/
          yield :block_start, statement.gsub(/\s*:\s*$/, ':')
        else
          yield :statement, statement
        end
      }
    end
  end
end
