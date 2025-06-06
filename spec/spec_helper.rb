# frozen_string_literal: true

require_relative '../lib/flashapi'

RSpec.configure do |config|
  # Use the documentation formatter for readable output
  config.default_formatter = 'doc' if config.files_to_run.one?

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Run specs in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed

  # Configure RSpec to focus on failures
  config.filter_run_when_matching :focus

  # Allow more verbose output when running an individual file
  if config.files_to_run.one?
    config.formatter = :documentation
  end

  # Print the 10 slowest examples and example groups
  config.profile_examples = 10

  # Configure shared context metadata behavior
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Allow rescue from load errors for optional dependencies
  config.when_first_matching_example_defined(:focus) do
    config.filter_run_including focus: true
    config.run_all_when_everything_filtered = true
  end

  # Expectations configuration
  config.expect_with :rspec do |expectations|
    # Enable only the newer, non-monkey-patching expect syntax
    expectations.syntax = :expect
    
    # Include additional matchers
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Mock configuration
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist
    mocks.verify_partial_doubles = true
    
    # Allow message expectations on nil
    mocks.allow_message_expectations_on_nil = false
  end

  # Warnings configuration - be strict about warnings in tests
  config.warnings = true

  # Seed global randomization in this process using the `--seed` CLI option
  Kernel.srand config.seed
end

# Custom matchers for FlashAPI
RSpec::Matchers.define :be_success_response do
  match do |response|
    parsed = Oj.load(response, symbol_keys: true)
    parsed[:success] == true && parsed[:status_code].between?(200, 299)
  end

  failure_message do |response|
    parsed = Oj.load(response, symbol_keys: true)
    "expected response to be successful, but got status: #{parsed[:status_code]}, success: #{parsed[:success]}"
  end
end

RSpec::Matchers.define :be_error_response do |expected_status|
  match do |response|
    parsed = Oj.load(response, symbol_keys: true)
    parsed[:success] == false && parsed[:status_code] == expected_status
  end

  failure_message do |response|
    parsed = Oj.load(response, symbol_keys: true)
    "expected response to be error with status #{expected_status}, but got status: #{parsed[:status_code]}, success: #{parsed[:success]}"
  end
end