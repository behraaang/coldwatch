require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # ActiveRecord encryption keys — read from env so dev keys never land in credentials.
    # Production deploys set these from Rails encrypted credentials or a secret manager.
    if ENV["RAILS_ENCRYPTION_PRIMARY_KEY"].present?
      config.active_record.encryption.primary_key            = ENV["RAILS_ENCRYPTION_PRIMARY_KEY"]
      config.active_record.encryption.deterministic_key      = ENV["RAILS_ENCRYPTION_DETERMINISTIC_KEY"]
      config.active_record.encryption.key_derivation_salt    = ENV["RAILS_ENCRYPTION_KEY_DERIVATION_SALT"]
    end
  end
end
