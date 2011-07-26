class O
	class Parser
		attr_reader :content

		class << self
			def compile content
				parser = Parser.new content
				parser.compile
			end
		end

		def initialize content
			@content = content
		end

		def compile
			script = ""
			indent_counts = 0
			block_start = false

			scan do |token, statement|
				case token
				when :block_start
					block_start = true
					statement = statement.sub(":", " do")
					script << statement << "\n"
				when :statement
					script << statement << "\n"
				when :indent
					indent_counts += 1
					script << "\t"*indent_counts
				when :undent
					script << "\t"*indent_counts
				when :dedent
					if block_start
						block_start = false
						script << "\t"*(indent_counts-1) + "end\n"
					else
						script << "\t"*(indent_counts-1)
					end
					indent_counts -= 1
				end
			end
			script
		end
		
	private
	
		def scan
			last_indent = 0

			content.scan(/(.*?)(\n+|\Z)/).each do |line, newline|

				_, indents, statement = line.match(/^(\t*)(.*)/).to_a

				# indent
				# a:
				#   b 1
				#   c:
				#     d 1
				#     e:
				#       f 1
				#   g 1
				indent = indents.count("\t")
				counts = indent - last_indent
				last_indent = indent

				if counts == 0
					yield :undent
				else
					counts.abs.times {
						yield (counts>0 ? :indent : :dedent)
					}
				end

				# statement
				if statement =~ /:\s*$/
					yield :block_start, statement.gsub(/\s*:\s*$/, ':')
				else
					yield :statement, statement
				end
			end


		end
	end
end
