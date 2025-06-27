#### Ruby (System)

**Environment Setup**
```bash
# Ruby uses Bundler for dependency isolation
ruby -v  # Verify system Ruby
gem install bundler

# Configure bundler for project
bundle config set --local path 'vendor/bundle'
```

**Project Init**
```bash
# Initialize Bundler
bundle init

# Basic project structure
mkdir -p lib spec
touch Rakefile README.md .gitignore

# Add to .gitignore
echo "vendor/\n.bundle/\n*.gem" > .gitignore
```

**Dependencies**
```bash
# Add gems to Gemfile
bundle add sinatra
bundle add rspec --group=test
bundle add rubocop --group=development

# Install all gems
bundle install

# Update gems
bundle update

# Execute in bundle context
bundle exec ruby app.rb
```

**Format & Lint**
```bash
# RuboCop for style
bundle add rubocop --group=development

# Run RuboCop
bundle exec rubocop
bundle exec rubocop -a  # Auto-correct

# Configure (.rubocop.yml)
AllCops:
  NewCops: enable
  TargetRubyVersion: 2.7
```

**Testing**
```bash
# RSpec setup
bundle add rspec --group=test
bundle exec rspec --init

# Run tests
bundle exec rspec
bundle exec rspec spec/model_spec.rb

# Minitest (built-in)
ruby test/test_helper.rb
```

**Build**
```bash
# Ruby is interpreted, no build needed
# Create gem if needed
gem build myapp.gemspec

# Package with Bundler
bundle package  # Vendors all gems
```

**Run**
```bash
# Run with bundler
bundle exec ruby lib/myapp.rb

# Run Sinatra app
bundle exec ruby app.rb

# Interactive console
bundle exec irb -r ./lib/myapp

# Rake tasks
bundle exec rake -T  # List tasks
bundle exec rake test
```
