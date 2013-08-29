[![Gem Version](https://badge.fury.io/rb/transpec.png)](http://badge.fury.io/rb/transpec) [![Dependency Status](https://gemnasium.com/yujinakayama/transpec.png)](https://gemnasium.com/yujinakayama/transpec) [![Build Status](https://travis-ci.org/yujinakayama/transpec.png?branch=master)](https://travis-ci.org/yujinakayama/transpec) [![Coverage Status](https://coveralls.io/repos/yujinakayama/transpec/badge.png)](https://coveralls.io/r/yujinakayama/transpec) [![Code Climate](https://codeclimate.com/github/yujinakayama/transpec.png)](https://codeclimate.com/github/yujinakayama/transpec)

# Transpec

**Transpec** automatically converts your specs into latest [RSpec](http://rspec.info/) syntax with static analysis.

This aims to facilitate smooth transition to RSpec 3.

See the following pages for the new RSpec syntax and the plan for RSpec 3:

* [Myron Marston » RSpec's New Expectation Syntax](http://myronmars.to/n/dev-blog/2012/06/rspecs-new-expectation-syntax)
* [RSpec's new message expectation syntax - Tea is awesome.](http://teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/)
* [Myron Marston » The Plan for RSpec 3](http://myronmars.to/n/dev-blog/2013/07/the-plan-for-rspec-3)

Note that Transpec does not yet support all conversions for the RSpec changes,
and also the changes for RSpec 3 is not fixed and may vary in the future.
So it's recommended to follow updates of both RSpec and Transpec.

## Example

Here's an example spec:

```ruby
describe Account do
  subject(:account) { Account.new(logger) }
  let(:logger) { mock('logger') }

  describe '#balance' do
    context 'initially' do
      it 'is zero' do
        account.balance.should == 0
      end
    end
  end

  describe '#close' do
    it 'logs an account closed message' do
      logger.should_receive(:account_closed).with(account)
      account.close
    end
  end

  describe '#renew' do
    context 'when the account is renewable and not closed' do
      before do
        account.stub(:renewable? => true, :closed? => false)
      end

      it 'does not raise error' do
        lambda { account.renew }.should_not raise_error
      end
    end
  end
end
```

Transpec would convert it to the following form:

```ruby
describe Account do
  subject(:account) { Account.new(logger) }
  let(:logger) { double('logger') }

  describe '#balance' do
    context 'initially' do
      it 'is zero' do
        expect(account.balance).to eq(0)
      end
    end
  end

  describe '#close' do
    it 'logs an account closed message' do
      expect(logger).to receive(:account_closed).with(account)
      account.close
    end
  end

  describe '#renew' do
    context 'when the account is renewable and not closed' do
      before do
        allow(account).to receive(:renewable?).and_return(true)
        allow(account).to receive(:closed?).and_return(false)
      end

      it 'does not raise error' do
        expect { account.renew }.not_to raise_error
      end
    end
  end
end
```

## Installation

```bash
$ gem install transpec
```

## Basic Usage

Before converting your specs:

* Make sure your project has `rspec` gem dependency `2.14` or later. If not, change your `*.gemspec` or `Gemfile` to do so.
* Run `rspec` and check if all the specs pass.

Then, run `transpec` with no arguments in the project root directory:

```bash
$ cd some-project
$ transpec
Processing spec/spec_helper.rb
Processing spec/spec_spec.rb
Processing spec/support/file_helper.rb
Processing spec/support/shared_context.rb
Processing spec/transpec/ast/scanner_spec.rb
Processing spec/transpec/ast/scope_stack_spec.rb
```

This will convert and overwrite all spec files in the `spec` directory.

After the conversion, run `rspec` again and check if all pass.

## Options

### `-d/--disable`

Disable specific conversions.

```bash
$ transpec --disable expect_to_receive,allow_to_receive
```

#### Available conversion types

Conversion Type     | Target Syntax                    | Converted Syntax
--------------------|----------------------------------|----------------------------
`expect_to_matcher` | `obj.should`                     | `expect(obj).to`
`expect_to_receive` | `obj.should_receive`             | `expect(obj).to receive`
`allow_to_receive`  | `obj.stub`                       | `allow(obj).to receive`
`deprecated`        | `obj.stub!`, `mock('foo')`, etc. | `obj.stub`, `double('foo')`

### `-n/--negative-form`

Specify negative form of `to` that is used in `expect` syntax.
Either `not_to` or `to_not`.
`not_to` is used by default.

```bash
$ transpec --negative-form to_not
```

### `-p/--no-parentheses-matcher-arg`

Suppress parenthesizing argument of matcher when converting
`should` with operator matcher to `expect` with non-operator matcher
(`expect` syntax does not directly support the operator matchers).
Note that it will be parenthesized even if this option is specified
when parentheses are necessary to keep the meaning of the expression.

```ruby
describe 'original spec' do
  it 'is example' do
    1.should == 1
    2.should > 1
    'string'.should =~ /str/
    [1, 2, 3].should =~ [2, 1, 3]
    { key: value }.should == { key: value }
  end
end

describe 'converted spec' do
  it 'is example' do
    expect(1).to eq(1)
    expect(2).to be > 1
    expect('string').to match(/str/)
    expect([1, 2, 3]).to match_array([2, 1, 3])
    expect({ key: value }).to eq({ key: value })
  end
end

describe 'converted spec with -p/--no-parentheses-matcher-arg option' do
  it 'is example' do
    expect(1).to eq 1
    expect(2).to be > 1
    expect('string').to match /str/
    expect([1, 2, 3]).to match_array [2, 1, 3]
    # With non-operator method, the parentheses are always required
    # to prevent the hash from being interpreted as a block.
    expect({ key: value }).to eq({ key: value })
  end
end
```

## Compatibility

Tested on MRI 1.9, MRI 2.0 and JRuby in 1.9 mode.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
