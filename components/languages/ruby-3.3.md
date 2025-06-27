#### Ruby 3.3

**Environment Setup**
```bash
# Ruby uses Bundler for dependency isolation
ruby -v  # Verify Ruby 3.3
gem install bundler
bundle config set --local path 'vendor/bundle'
```

**Project Init**
```bash
# Initialize Bundler
bundle init

# Rails project
gem install rails
rails new myapp

# Basic Ruby project
mkdir -p lib spec
touch Gemfile Rakefile README.md .gitignore
```

**Dependencies**
```bash
# Add to Gemfile
bundle add sinatra
bundle add rspec --group=test
bundle add rubocop --group=development

# Install dependencies
bundle install

# Update dependencies
bundle update

# Execute with bundle context
bundle exec rake
```

**Format & Lint**
```bash
# RuboCop for linting/formatting
bundle add rubocop --group=development

# Run RuboCop
bundle exec rubocop
bundle exec rubocop -a  # Auto-correct

# Configure in .rubocop.yml
echo "AllCops:\n  NewCops: enable" > .rubocop.yml
```

**Testing**
```bash
# RSpec setup
bundle add rspec --group=test
bundle exec rspec --init

# Run tests
bundle exec rspec
bundle exec rspec spec/specific_spec.rb
bundle exec rspec -fd  # Full description format

# Rails testing
bundle exec rails test
bundle exec rails test test/models/user_test.rb
```

**Build**
```bash
# Ruby is interpreted, no build needed
# For gems:
gem build myapp.gemspec

# For Rails assets:
bundle exec rails assets:precompile
```

**Run**
```bash
# Run Ruby script
ruby lib/myapp.rb

# With Bundler context
bundle exec ruby lib/myapp.rb

# Rails server
bundle exec rails server
bundle exec rails console

# Sinatra app
bundle exec ruby app.rb
```
