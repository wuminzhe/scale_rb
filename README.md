# ScaleRb

It is still under heavy development. Use the latest version.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "scale_rb", "~> 0.4.2"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install scale_rb

## Run examples

```bash
git clone https://github.com/wuminzhe/scale_rb.git
cd scale_rb
bundle install
CONSOLE_LEVEL=debug bundle exec ruby examples/http_client_1.rb
```

## Development

### Run devcontainer

Open the project in vscode, then in the command palette, type `Reopen in Container` to open the project in a devcontainer.

![image](https://github.com/user-attachments/assets/39af785c-5570-46df-9e6e-bf816e7f7b68)


After the devcontainer is opened, you can run the following commands:

1. Tests:

   ```bash
   bundle exec rspec
   ```

2. Examples:
   ```bash
   bundle exec ruby examples/http_client_1.rb
   ```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wuminzhe/scale_rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/wuminzhe/scale_rb/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ScaleRb project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/scale_rb/blob/master/CODE_OF_CONDUCT.md).
