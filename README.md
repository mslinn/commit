# `Commit` [![Gem Version](https://badge.fury.io/rb/commit.svg)](https://badge.fury.io/rb/commit)

Runs git commit without prompting for a message.
Files larger than 2 GB are added to .gitignore instead of being committed.

This gem is further described in [A Streamlined Git Commit](https://mslinn.com/git/1050-commit.html).


## Installation

1) [Install the `rugged` gem.](https://mslinn.com/git/4400-rugged.html)
2) Type:

    ```ruby
    gem install commit
    ```


## Usage

```shell
$ commit [options] [file...]
```

Where options are:
  -a "tag message"
  -m "commit message"
  -v 0 # Minimum verbosity
  -v 1 # Default verbosity
  -v 2 # Maximum verbosity


### Examples

```shell
$ commit  # The default commit message is just a single dash (-)
$ commit -v 0
$ commit -m "This is a commit message"
$ commit -v 0 -m "This is a commit message"
$ commit -a 0.1.2
```


## Development

After checking out this git repository, install dependencies by typing:

```shell
$ bin/setup
```

You should do the above before running Visual Studio Code.


### Run the Tests

```shell
$ bundle exec rake test
```


### Interactive Session

The following will allow you to experiment:

```shell
$ bin/console
```


### Local Installation

To install this gem onto your local machine, type:

```shell
$ bundle exec rake install
```


### To Release A New Version

To create a git tag for the new version, push git commits and tags,
and push the new version of the gem to https://rubygems.org, type:

```shell
$ bundle exec rake release
```


## Contributing

Bug reports and pull requests are welcome at https://github.com/mslinn/commit.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
