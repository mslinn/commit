class GitCommit
  QUIET = 0
  NORMAL = 1
  VERBOSE = 2
  ANNOYING = 3
  STFU = 4


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

  # Handles single quotes, spaces and square braces in the given string
  def escape(string)
    string.gsub("'", "\\\\'")
          .gsub(' ', '\\ ')
          .gsub('[', '\\[')
          .gsub(']', '\\]')
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
      puts msg.yellow unless @options[:verbosity] == QUIET

      newline = needs_newline('.gitignore') ? "\n" : ''
      File.write('.gitignore', "#{newline}#{filename}\n", mode: 'a')
      @gitignore_dirty = true
    elsif filename == '.gitignore'
      @gitignore_dirty = true
    else
      if @commit_size + file_size >= MAX_SIZE / 2.0
        # Defeat formatter
        commit_push 'A portion of the files to be committed is being pushed now because they are large.'
      end
      puts "Adding '#{escape filename}'".green unless @options[:verbosity] == QUIET
      run ['git', 'add', escape(filename)], verbose: @options[:verbosity] >= VERBOSE
    end
    @change_count += 1
    @commit_size += file_size
  end

  # Assumes .gitignore is never large
  def large_file?(filename)
    File.size(filename) > MAX_SIZE if File.exist?(filename)
  end

  def needs_newline(filename)
    return false unless File.exist? filename

    file_contents = File.read filename
    file_contents.nil? || file_contents.empty? || !file_contents.end_with?("\n")
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
    run ['git', 'add', '--all'], verbose: @options[:verbosity] >= VERBOSE
    @repo.status do |path, flags|
      next if flags.include? :ignored

      if File.directory? path
        scan_directory path
      else
        file_add path
      end
    end
    if @gitignore_dirty
      puts 'Changing .gitignore'.green unless @options[:verbosity] == QUIET
      run 'git add .gitignore', verbose: @options[:verbosity] >= 2
      @change_count += 1
    end
    return unless @change_count.zero?

    puts 'No changes were detected to this git repository.'.green if @options[:verbosity] >= VERBOSE
    exit
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
