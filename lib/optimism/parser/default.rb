class Optimism
  module Parser
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
              statement = statement.sub(/\s*:/, " do")
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
                script << INDENT*(indent_counts) + "end\n"
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
            a = line.match(/^(\s*)(.*)/)
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
              blk.call [:block_start, statement.gsub(/\s*:\s*$/, ':')]  # jruby need []
            else
              blk.call [:statement, statement]
            end
          }
        end
      end

      # convert variable assigment
      #
      #   a = 1
      #   b <<-OPTIMISM_EOF0
      #     c = 2
      #     _.c = 3
      #     foo.d = 4
      #   OPTIMISM_EOF0
      #   puts 1
      #   'a' == 'a'
      #   'a' =~ /./
      #  
      # to
      #
      #    _.a = 1
      #    b <<-OPTIMISM_EOF0
      #      _.c = 2
      #      _.c = 3
      #      _.foo.d = 4
      #   OPTIMISM_EOF0
      #   puts 1
      #   ...
      #
      class LocalVariable2Method < Filter
        LOCAL_VARIABLE_PAT = /^(\s*)([a-z0-9][a-zA-Z0-9_.]*\s*=[^~=])/

        def initialize(content)
          @content = content
        end

        def evaluate
          contents = content.split("\n").each.with_object([]) do |line, m|
            m << line.sub(LOCAL_VARIABLE_PAT, "\\1_.\\2")
          end

          contents.join("\n") + "\n"
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

        @optimism
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
        content = StringBlock2RubyBlock.new(content).evaluate 
        content = LocalVariable2Method.new(content).evaluate

        @optimism.instance_eval(content)

        @optimism
      end
    end
  end
end

Optimism.add_extension ".rb", Optimism::Parser::Default

# vim: fdn=4
