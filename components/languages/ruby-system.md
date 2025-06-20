#### Ruby (System)

**Bundler Setup**:
- Init: `bundle init`
- Add gem: `bundle add sinatra`
- Install: `bundle install`
- Execute: `bundle exec rake`

**Testing**:
```ruby
# Minitest (built-in)
require 'minitest/autorun'
class TestExample < Minitest::Test
  def test_truth
    assert_equal 2, 1 + 1
  end
end

# RSpec
bundle add rspec --group=test
bundle exec rspec --init
```

**Development**:
- REPL: `irb` or `pry` (better)
- Lint: `bundle add rubocop --group=development`

**Note**: Gems install to `~/.bundle`, bins to `~/.local/bin`
