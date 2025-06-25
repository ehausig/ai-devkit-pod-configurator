#### Ruby 3.3

**Ruby 3.3 Features**: Prism parser, YJIT improvements, Range#overlap?

**Project Setup**:
- `bundle init` - Create Gemfile
- `bundle add rails` - Add dependencies
- `bundle install` - Install gems
- `bundle exec command` - Run with bundled gems

**Testing**:
```ruby
# RSpec
bundle add rspec --group=test
bundle exec rspec --init
bundle exec rspec

# Rails default
bundle exec rails test
```

**Rails**: `rails new myapp` → `bin/rails server`

**Development**:
- Console: `irb` or `bin/rails console`
- Lint: `bundle add rubocop --group=development`
- Test continuously: `bundle add guard-rspec`
