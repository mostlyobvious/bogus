require 'simplecov'
begin
  require "coveralls"

  # coveralls 0.8.x pins Net::HTTP#ssl_version to TLSv1, which Coveralls no
  # longer accepts. Force TLS 1.2 while keeping the rest of its client setup.
  Coveralls::API.singleton_class.prepend(Module.new do
    def build_client(uri)
      super.tap do |client|
        client.ssl_version = 'TLSv1_2'
      end
    end

    private :build_client
  end)

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter])
rescue LoadError
  warn "warning: coveralls gem not found; skipping Coveralls"
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
end

SimpleCov.start do
  add_filter "/spec/"
end

require 'bogus'
require 'dependor/rspec'

require_relative 'support/sample_fake'
require_relative 'support/fake_creator_of_fakes'
require_relative 'support/matchers'
require_relative 'support/shared_examples_for_keyword_arguments'
require_relative 'support/ruby_features'

RSpec.configure do |config|
  config.mock_with :rspec
end
