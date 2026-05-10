ENV["RAILS_ENV"] ||= "test"

# ActiveRecord encryption keys must already be present in the OS env when
# Rails boots (config/application.rb reads them eagerly). `bin/rails test`
# loads Rails before this file runs, so setting them here would be too late.
# - Local docker:  set via .env.development on the web container.
# - CI:           set via .github/workflows/ci.yml env block.
# - Bare host:    export them yourself (test-only fake values are fine).

require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"  # provides Object#stub used by HTTP stubs and service-method swaps

# Shared test helpers (HTTP stubbing, BIP84 spec test vectors).
Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    # Short, fake xpub-prefixed strings used by tests that only exercise
    # validations / persistence and never derive child keys. Kept under
    # 100 chars so the xpub-leakage CI guard never matches them.
    FAKE_ZPUB = "zpub" + "X" * 50
    FAKE_VPUB = "vpub" + "X" * 50

    # Real BIP84 spec test vector zpubs are loaded from the fixtures
    # directory (excluded by scripts/grep-xpub-guard.sh). Used only by
    # AddressDerivationTest where the actual derived addresses matter.
    BIP84_VECTORS = YAML.load_file(
      Rails.root.join("test/fixtures/files/test_xpubs.yml")
    ).freeze
  end
end
