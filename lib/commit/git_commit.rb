require 'active_support'
require 'active_support/core_ext/numeric/conversions'
require 'colorator'
require 'optparse'
require 'rugged'

KB = 1024
MB = KB * KB
GB = KB * MB
# File size limits for git commits depend on the type of your GitHub account:
GITHUB_FREE             = 100 * MB
GITHUB_PRO              = 2 * GB
GITHUB_TEAM             = 4 * GB
GITHUB_ENTERPRISE_CLOUD = 5 * GB

GIT_LFS_ENABLED = false

MAX_SIZE = GIT_LFS_ENABLED ? GITHUB_FREE : 100 * MB # Adjust this to suit your GitHub account

# Originally written in bash by Mike Slinn 2005-09-05
# Converted to Ruby and added MAX_SIZE 2024-12-11
# See https://docs.github.com/en/repositories/working-with-files/managing-large-files/configuring-git-large-file-storage
# See https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
class GitCommit
  ActiveSupport::NumberHelper.alias_method :to_human, :number_to_human_size

  def initialize(default_branch: 'master')
    @branch = default_branch
    @commit_size = 0
    @gitignore_dirty = false
    @nh = ActiveSupport::NumberHelper
  end

  def commit_push(msg = '-')
    puts msg.yellow if msg
    msg = @options[:commit_message] if @options[:commit_message]
    discover_branch

    puts "Committing with message '#{msg}'".green unless @options[:verbosity].zero?
    run("git commit -m '#{msg}' 2>&1 | sed -e '/^X11/d' -e '/^Warning:/d'", verbose: @options[:verbosity] >= 2)
    # @repo.push 'origin', ['refs/heads/master'] # Needs a callback to handle authentication
    puts "Pushing to origin #{@branch}".green unless @options[:verbosity].zero?
    run("git push origin #{@branch} --tags 3>&1 1>&2 2>&3 | sed -e '/^X11/d' -e '/^Warning:/d'", verbose: @options[:verbosity] >= 2)
    @change_count = 0
    @commit_size = 0
  end

  def discover_branch
    if @repo.branches.entries.empty?
      # puts "\nYour git repository is empty. Please add at least one file before committing.".red
      # exit 4
      run "git branch -M #{@branch}"
    else
      @branch = @repo.head.name.sub(%r{^refs/heads/}, '')
    end
  end

  def git_project?
    run 'git rev-parse 2> /dev/null', verbose: false
  end

  def large_files
    large = []
    @repo.status do |path, flags|
      puts "#{path} #{flags}" if @options[:verbosity].positive?
      if File(path).dir?
        scan_dir path
      elsif large_file?(filename)
        large << path.gsub(' ', '\ ').gsub('[', '\[').gsub(']', '\]')
      end
    end
    large
  end

  def main
    @options = parse_options
    repo_dir = ARGV.empty? ? Dir.pwd : ARGV[0]
    Dir.chdir(repo_dir) unless ARGV.empty?
    if git_project?
      process_tag # Exits if a tag was created
      @repo = Rugged::Repository.new repo_dir
      recursive_add
      commit_push if @commit_size.positive?
    else
      puts "Error: '#{repo_dir}' does not contain a git project".red
      exit 3
    end
  end

  def process_tag
    tag = @options[:tag]
    return unless tag

    run("git tag -a #{tag} -m 'v#{tag}'", verbose: @options[:verbosity] >= 2)
    run('git push origin --tags', verbose: @options[:verbosity] >= 2)
    exit
  end

  # @param command can be a String or an Array of String
  def run(command, verbose: true, do_not_execute: false)
    if command.instance_of?(Array)
      puts command.join(' ') if verbose
      Kernel.system(*command) unless do_not_execute
    else
      puts command if verbose
      `#{command}`.chomp unless do_not_execute
    end
  end
end
