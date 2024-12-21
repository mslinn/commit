require 'colorator'
require 'fileutils'
require 'pathname'

def require_subdirectory(dir)
  Dir[File.join(dir, '*.rb')].each do |file|
    require file unless file == __FILE__
  end
end

require_subdirectory File.realpath(__dir__) # Require all Ruby files in 'lib/', except this file
Pathname(__dir__).children.select(&:directory?).each do |directory|
  require_subdirectory directory.to_s
end

module Commit
  def self.main
    @options = parse_options
    puts "TODO: write main implementation in lib/Commit/cli.rb".yellow
  end
end