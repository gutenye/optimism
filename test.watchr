# lib/**/*.rb
watch %r~lib/(.*)\.rb~ do |m|
	test "spec/test_spec.rb"
end

# spec/**/*_spec.rb
watch %r~spec/.*_spec\.rb~ do |m|
	test m[0]
end

def test path
	cmd = "rspec #{path}"
	puts cmd
	system cmd
end
