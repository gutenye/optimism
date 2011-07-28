# lib/**/*.rb
watch %r~lib/(.*)\.rb~ do |m|
	test "spec/#{m[1]}_spec.rb"
end

# spec/**/*_spec.rb
watch %r~spec/.*_spec\.rb~ do |m|
	test m[0]
end

# Ctrl-\
Signal.trap('QUIT') do
  puts "--- Running all tests ---\n\n"
	test "spec"
end

def test path
	cmd = "rspec #{path}"
	puts cmd
	system cmd
end

