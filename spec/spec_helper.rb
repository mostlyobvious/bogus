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
