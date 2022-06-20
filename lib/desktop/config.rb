# =============================================================================
# Copyright (C) 2019-present Alces Flight Ltd.
#
# This file is part of Flight Desktop.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# Flight Desktop is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with Flight Desktop. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on Flight Desktop, please visit:
# https://github.com/alces-flight/flight-desktop
# ==============================================================================
require_relative 'type'
require 'xdg'
require 'fileutils'

require 'flight_configuration'

module Flight
  def self.config
    @config ||= Desktop::Configuration.load
  end

  def self.env
    @env ||= 'production'
  end

  def self.root
    @root ||= File.expand_path('../..', __dir__)
  end
end

module Desktop
  class Configuration
    extend FlightConfiguration::DSL

    class << self
      # Override the config files to use the legacy paths
      def config_files(*_)
        @config_files ||= [global_config, user_config]
      end

      def global_config
        @global_config ||= Pathname.new('../../etc/config.yml').expand_path(__dir__)
      end

      def user_config
        @user_config ||= desktop_path.join('config.yml').expand_path(xdg_config.home)
      end

      def desktop_path
        @desktop_path ||= Pathname.new('flight/desktop')
      end

      def xdg_config
        @xdg_config ||= XDG::Config.new
      end

      def xdg_data
        @xdg_data ||= XDG::Data.new
      end

      def xdg_cache
        @xdg_cache ||= XDG::Cache.new
      end
    end

    application_name 'desktop'

    attribute :vnc_passwd_program, default: '/usr/bin/vncpasswd'
    attribute :vnc_server_program, default: 'libexec/vncserver',
              transform: relative_to(root_path)

    # TODO: Validate it is an [String]
    attribute :type_paths, default: ['etc/types'], transform: ->(paths) do
      paths.each { |p| File.expand_path(Flight.root) }
    end
    attribute :websockify_paths, default: ['/usr/bin/websockify'], transform: ->(paths) do
      paths.each { |p| File.expand_path(Flight.root) }
    end
    attribute :session_path, default: desktop_path.join('sessions'),
              transform: relative_to(xdg_cache.home)
    attribute :bg_image, default: 'etc/assets/backgrounds/default.jpg',
              transform: relative_to(root_path)

    attribute :access_hosts, default: []
    attribute :access_ip, required: false, defualt: ->() { NetworkUtils.primary_ip }
    attribute :access_host, required: false

    attribute :global_state_path, default: 'var/lib/desktop',
              transform: relative_to(root_path)
    attribute :user_state_path, default: desktop_path.join('state'),
              transform: relative_to(xdg_data.home)

    attribute :session_env_path, default: '/usr/bin:/usr/sbin:/bin:/sbin'
    attribute :session_env_override, default: true

    attribute :geometry, default: '1024x768'
    attribute :desktop_type, required: false
    attribute :hooks_dir, default: 'libexec/desktop/hooks',
              transform: relative_to(Flight.root)

    attribute :timeout, default: 2

    attribute :global_log_path, default: 'log/desktop', transform: relative_to(root_path)
    attribute :user_log_path, default: 'log/desktop', transform: relative_to(xdg_cache.home)

    # NOTE: flight_configuration does not have support for transient dependencies
    # between attributes. Instead a wrapper method is required.
    def access_host_or_ip
      access_host || access_ip
    end

    def save_key(key, value, global:)
      # Load the existing data
      path = global ? self.class.global_config : self.class.user_config
      if File.exists?(path)
        # Ensure all keys are loaded as symbols
        data = YAML.load(File.read(path), symbolize_names: true)
      else
        data = {}
      end

      # Update the data
      data[key.to_sym] = value

      # Ensure all keys are saved as strings
      data = data.map { |k, v| [k.to_s, v] }.to_h
      FileUtils.mkdir_p File.dirname(path)
      File.write(path, YAML.dump(data))
    end
  end

  module Config
    class << self
      DESKTOP_DIR_SUFFIX = File.join('flight','desktop')

      # Define the Configuration delegates
      Configuration.attributes.each do |key, _|
        define_method(key) { Flight.config.send(key) }
      end

      def root
        Flight.root
      end

      def functional?
        File.executable?(vnc_passwd_program) &&
          File.executable?(vnc_server_program)
      end

      def set_geometry(geometry, global: false)
        raise 'invalid geometry string' if geometry !~ /^[0-9]+x[0-9]+$/
        Flight.config.save_key('geometry', geometry, global: global)
      end
    end
  end
end
