# require 'simplecov'
# SimpleCov.start do
#   enable_coverage :branch
#   primary_coverage :branch
# end

require "pp"
# require "spec_helper"
require "fakefs/spec_helpers"

ENV['flight_ENVIRONMENT'] ||= "test"

require_relative "../lib/desktop/config"

Flight.config

RSpec.configure do |config|
  config.before(:suite) do
    # Our use of FakeFS can cause problems when translations and localizations
    # are lazily loaded.  We ensure that all needed localizations are loaded
    # prior to the suite running.
    # I18n.localize(Time.now)

    # Flight Desktop doesn't currently support different config files for
    # different environments, so we mutate the config for the test environment
    # here instead.
    #
    # Where the code base accesses a configuration value as `Config.<method>`
    # it can be set here as `Flight.config.<method> = ...`.
    Flight.config.session_path = File.join(Flight.root, 'spec/fixtures/sessions')
  end
end
