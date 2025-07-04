require 'pathname'
require 'colorator'
require 'fileutils'

def require_subdirectory(dir)
  Dir[File.join(dir, '*.rb')].each do |file|
    require file unless file == __FILE__
  end
end

git_dir = `git rev-parse --show-toplevel`.chomp
if git_dir.empty?
  puts 'This script must be run from within a git repository.'.red
  exit 1
end
Dir.chdir(git_dir) # Change to the root of the git repository

require_subdirectory File.realpath(__dir__) # Require all Ruby files in 'lib/', except this file
Pathname(__dir__).children.select(&:directory?).each do |directory|
  require_subdirectory directory.to_s
end
