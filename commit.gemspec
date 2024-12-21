require_relative 'lib/commit/version'

Gem::Specification.new do |spec|
  host = 'https://github.com/mslinn/commit'

  spec.authors               = ['Mike Slinn']
  spec.bindir                = 'exe'
  spec.executables           = ['commit']
  spec.description           = <<~END_DESC
    Performs the following:
      1) git add
      2) git commit
      3) git push
      Works with Git LFS
  END_DESC
  spec.email                 = ['mslinn@mslinn.com']
  spec.files                 = Dir['.rubocop.yml', 'LICENSE.*', 'Rakefile', '{lib,spec}/**/*', '*.gemspec', '*.md']
  spec.homepage              = 'https://github.com/mslinn/commit'
  spec.license               = 'MIT'
  spec.metadata = {
    'allowed_push_host' => 'https://rubygems.org',
    'bug_tracker_uri'   => "#{host}/issues",
    'changelog_uri'     => "#{host}/CHANGELOG.md",
    'homepage_uri'      => spec.homepage,
    'source_code_uri'   => host,
  }
  spec.name                 = 'commit'
  spec.post_install_message = <<~END_MESSAGE

    Thanks for installing #{spec.name}!

  END_MESSAGE
  spec.require_paths         = ['lib']
  spec.required_ruby_version = '>= 3.1.0'
  spec.summary               = 'Write summary of what the gem is for'
  spec.version               = Commit::VERSION
  spec.add_dependency 'activesupport'
  spec.add_dependency 'colorator'
  spec.add_dependency 'optparse'
  spec.add_dependency 'rugged'
end
