require "spec_helper"
require "pp"
require "fakefs/spec_helpers"

require_relative "../lib/desktop/config"

Flight.config

RSpec.configure do |config|
  config.before(:suite) do
    # Flight Desktop doesn't currently support different config files for
    # different environments, so we mutate the config for the test environment
    # here instead.
    #
    # Where the code base accesses a configuration value as `Config.<method>`
    # it can be set here as `Flight.config.<method> = ...`.
    Flight.config.session_path = File.join(Flight.root, 'spec/fixtures/sessions')
  end
end
