#!/usr/bin/env ruby

require 'active_support'
require 'active_support/core_ext/numeric/conversions'
require 'colorator'
require 'optparse'
require 'rugged'

# Originally written in bash by Mike Slinn 2005-09-05
# Converted to Ruby and added MAX_SIZE 2024-12-11
# See https://docs.github.com/en/repositories/working-with-files/managing-large-files/configuring-git-large-file-storage
# See https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
class GitCommit
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

  ActiveSupport::NumberHelper.alias_method :to_human, :number_to_human_size

  def initialize(default_branch: 'master')
    @branch = default_branch
    @gitignore_dirty = false
    @nh = ActiveSupport::NumberHelper
    @commit_size = 0
    @repo = Rugged::Repository.new(ARGV.empty? ? '.' : ARGV[0])
    Dir.chdir(ARGV[0])
  end

  # Needs absolute path or the path relative to the current directory, not just the name of the directory
  def add_recursively(name)
    Dir.entries(name).each do |entry|
      path = "#{name}/#{entry}"
      if File.directory(entry)
        scan_directory path
      else
        file_add path
      end
    end
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

  # @param filename [String] Must be a path relative to the git root
  def file_add(filename)
    file_size = File.exist?(filename) ? File.size(filename) : 0
    if large_file?(filename)
      msg = <<~MESSAGE
        Not adding '#{filename}' because the git file size limit is #{@nh.to_human MAX_SIZE},
        however the file is #{@nh.to_human file_size}.
        The file will be added to .gitignore.
      MESSAGE
      puts msg.yellow unless @options[:verbosity].zero?

      newline = needs_newline('.gitignore') ? "\n" : ''
      File.write('.gitignore', "#{newline}#{filename}\n", mode: 'a')
      @gitignore_dirty = true
    elsif filename == '.gitignore'
      @gitignore_dirty = true
    else
      commit_push('A portion of the files to be committed is being pushed now because they are large.') if @commit_size + file_size >= MAX_SIZE / 2.0
      puts "Adding '#{escape filename}'".green unless @options[:verbosity].zero?
      run ['git', 'add', escape(filename)], verbose: @options[:verbosity] >= 2
    end
    @change_count += 1
    @commit_size += file_size
  end

  # Handles single quotes, spaces and square braces in the given string
  def escape(string)
    string.gsub("'", "\\\\'").gsub(' ', '\\ ').gsub('[', '\\[').gsub(']', '\\]')
  end

  def git_project?
    run 'git rev-parse 2> /dev/null', verbose: false
  end

  # Assumes .gitignore is never large
  def large_file?(filename)
    File.size(filename) > MAX_SIZE if File.exist?(filename)
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

  def commit_push(msg = nil)
    puts msg.yellow if msg
    msg = @options[:message] if @options[:message]
    discover_branch
    run("git commit -m '#{msg}' 2>&1 | sed -e '/^X11/d' -e '/^Warning:/d'", verbose: false)
    # @repo.push 'origin', ['refs/heads/master'] # Needs a callback to handle authentication
    puts "Pushing to origin #{@branch}".green unless @options[:verbosity].zero?
    run("git push origin #{@branch} --tags 3>&1 1>&2 2>&3 | sed -e '/^X11/d' -e '/^Warning:/d'", verbose: false)
    @change_count = 0
    @commit_size = 0
  end

  def main
    @options = parse_options
    if git_project?
      process_tag # Exits if a tag was created
      recursive_add
      commit_push if @commit_size.positive?
    else
      puts "Error: '#{Dir.pwd}' is not a git project".red
      exit 3
    end
  end

  def needs_newline(filename)
    return false unless File.exist? filename

    file_contents = File.read filename
    file_contents.nil? || file_contents.empty? || !file_contents.end_with?("\n")
  end

  def process_tag
    tag = @options[:tag]
    return unless tag

    run("git tag -a #{tag} -m 'v#{tag}'", verbose: false)
    run('git push origin --tags', verbose: false)
    exit
  end

  # Exclude big files, git add all others
  # @repo.status returns the following values for flags:
  #  - +:index_new+: the file is new in the index
  #  - +:index_modified+: the file has been modified in the index
  #  - +:index_deleted+: the file has been deleted from the index
  #  - +:worktree_new+: the file is new in the working directory
  #  - +:worktree_modified+: the file has been modified in the working directory
  #  - +:worktree_deleted+: the file has been deleted from the working directory
  def recursive_add
    @change_count = 0
    @repo.status do |path, flags|
      next if flags.include? :ignored

      if File.directory? path
        scan_directory path
      else
        file_add path
      end
    end
    if @gitignore_dirty
      puts 'Changing .gitignore'.green unless @options[:verbosity].zero?
      run 'git add .gitignore', verbose: @options[:verbosity] >= 2
      @change_count += 1
    end
    return unless @change_count.zero?

    puts 'No changes were detected to this git repository.'.green if @options[:verbosity].positive?
    exit
  end

  # @param command can be a String or an [String]
  def run(command, verbose: true, do_not_execute: false)
    if verbose
      if command.instance_of?(Array)
        puts command.join ' '
      else
        puts command
      end
    end
    # `#{command}`.chomp unless do_not_execute
    Kernel.system(*command) unless do_not_execute
  end

  def scan_directory(path)
    Dir.children(path) do |name|
      child_path = "#{path}/#{name}"
      if File.directory? child_path
        scan_directory child_path
      else
        file_add child_path
      end
    end
  end
end
