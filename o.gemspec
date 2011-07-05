$: << "."
require "version"

Gem::Specification.new do |s|
	s.name = "o"
	s.version = O::VERSION::IS
	s.summary = "a configuration libraray for Ruby"
	s.description = <<-EOF
a coonfiguration libraray for Ruby
	EOF

	s.author = "Guten"
	s.email = "ywzhaifei@Gmail.com"
	s.homepage = "http://github.com/GutenYe/o"
	s.rubyforge_project = "xx"

	s.files = `git ls-files`.split("\n")
	#s.executables = ["x"]

	#s.add_dependency "x"
end
