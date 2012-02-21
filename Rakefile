sudo = Process.pid==0 ? "" : "sudo"

desc "build a gem file"
task :release do
	run "gem build optimism.gemspec"
	run "gem push *.gem"
  run "#{sudo} gem install *.gem"
	run "rm *.gem"
end

desc "install a gem file"
task :install do
	run "gem build optimism.gemspec"
	run "#{sudo} gem install *.gem"
	run "rm *.gem"
end

desc "autotest with watchr"
task :test do
	run "watchr optimism.watchr"
end

desc "testing the libraray"
namespace :test do
	task :all do
		run "rspec spec"
	end
end

desc "run yard server --reload"
task :doc do
	run "yard server --reload"
end

desc "clean up"
task :clean do
	run "rm *.gem"
end

def run cmd
	puts cmd
	system cmd
end
