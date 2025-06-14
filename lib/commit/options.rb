require 'colorator'
require 'optparse'

class GitCommit
  def help(msg = nil)
    printf "Error: #{msg}\n\n".yellow unless msg.nil?
    msg = <<~HELP
      commit v#{Commit::VERSION}

      Runs git commit without prompting for a message.
      Files larger than #{@nh.to_human MAX_SIZE} are added to .gitignore instead of being committed.

      Usage: commit [options]
      Where options are:
        -a "tag message"
        -m "commit message"
        -v 0 # Minimum verbosity
        -v 1 # Default verbosity
        -v 2 # Maximum verbosity

      Examples:
        commit  # The default commit message is just a single dash (-)
        commit -v 0
        commit -m "This is a commit message"
        commit -v 0 -m "This is a commit message"
        commit -a 0.1.2

      This gem is further described in https://mslinn.com/git/1050-commit.html
    HELP
    puts msg.yellow
    exit 1
  end

  def parse_options
    options = { message: '-', verbosity: 1 }
    OptionParser.new do |parser|
      parser.program_name = File.basename __FILE__
      @parser = parser

      parser.on('-a', '--tag TAG_MESSAGE', 'Specify tag message')
      parser.on('-m', '--message COMMIT_MESSAGE', 'Specify commit message')
      parser.on('-v', '--verbosity VERBOSITY', Integer, 'Verbosity (0..2)')

      parser.on_tail('-h', '--help', 'Show this message') do
        help
      end
    end.order!(into: options)
    help "Invalid verbosity value (#{options[:verbosity]})." if options[:verbosity].negative? || options[:verbosity] > 2
    if ARGV.length > 1
      help <<~END_MSG
        Incorrect syntax.
        After removing the options, the remaining command line was:
        #{ARGV.join ' '}
      END_MSG
    end
    options
  end
end
