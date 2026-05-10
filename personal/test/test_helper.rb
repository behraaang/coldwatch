ENV["RAILS_ENV"] ||= "test"

# Set test-only ActiveRecord encryption keys before the Rails environment
# boots, so models that declare `encrypts :xpub` etc. can read/write
# encrypted columns under `bin/rails test` without a real master.key.
# These values exist solely for the test suite and have no security value.
ENV["RAILS_ENCRYPTION_PRIMARY_KEY"]         ||= "test_primary_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
ENV["RAILS_ENCRYPTION_DETERMINISTIC_KEY"]   ||= "test_deterministic_key_aaaaaaaaaaaaaaaaaaaaaaa"
ENV["RAILS_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "test_derivation_salt_aaaaaaaaaaaaaaaaaaaaaaaaa"

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
