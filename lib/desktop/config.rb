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
require 'tty-config'
require 'fileutils'

require 'flight_configuration'

module Flight
  def self.config
    @config ||= Desktop::Configuration.load
  end

  def self.env
    @env ||= ENV['flight_ENVIRONMENT'] || 'production'
  end

  def self.root
    @root ||= if env == 'production' && ENV['flight_ROOT']
                File.expand_path(ENV['flight_ROOT'])
              else
                File.expand_path('../..', __dir__)
              end
  end
end

module Desktop
  class Configuration
    extend FlightConfiguration::DSL

    class << self
      # Override the config files with the original set
      def config_files(*_)
        @config_files ||= [
          # Apply the legacy config
          Pathname.new('../../etc/config.yml').expand_path(__dir__),
          root_path.join("etc/#{application_name}.yaml"),
          root_path.join("etc/#{application_name}.#{Flight.env}.yaml"),
          root_path.join("etc/#{application_name}.local.yaml"),
          root_path.join("etc/#{application_name}.#{Flight.env}.local.yaml"),
        ]
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

    attribute :log_dir, default: 'log/desktop',
              transform: ->(path) do
                root = if Process.euid == 0
                         root_path
                       else
                         xdg_cache.home
                       end
                File.expand_path(path, root)
              end

    # NOTE: flight_configuration does not have support for transient dependencies
    # between attributes. Instead a wrapper method is required.
    def access_host_or_ip
      access_host || access_ip
    end
  end

  module Config
    class << self
      DESKTOP_DIR_SUFFIX = File.join('flight','desktop')

      # Define the Configuration delegates
      Configuration.attributes.each do |key, _|
        define_method(key) { Flight.config.send(key) }
      end

      def data
        @data ||= TTY::Config.new.tap do |cfg|
          cfg.append_path(File.join(root, 'etc'))
          begin
            cfg.read
          rescue TTY::Config::ReadError
            nil
          end
        end
      end

      def save_data
        FileUtils.mkdir_p(File.join(root, 'etc'))
        data.write(force: true)
      end

      def data_writable?
        File.writable?(File.join(root, 'etc'))
      end

      def user_data
        @user_data ||= TTY::Config.new.tap do |cfg|
          xdg_config.all.map do |p|
            File.join(p, DESKTOP_DIR_SUFFIX)
          end.each(&cfg.method(:append_path))
          begin
            cfg.read
          rescue TTY::Config::ReadError
            nil
          end
        end
      end

      def save_user_data
        FileUtils.mkdir_p(
          File.join(
            xdg_config.home,
            DESKTOP_DIR_SUFFIX
          )
        )
        user_data.write(force: true)
      end

      def root
        @root ||= File.expand_path(File.join(__dir__, '..', '..'))
      end

      def functional?
        File.executable?(vnc_passwd_program) &&
          File.executable?(vnc_server_program)
      end

      def geometry
        user_data.fetch(
          :geometry,
          default: data.fetch(
            :geometry,
            default: '1024x768'
          )
        )
      end

      def set_geometry(geometry, global: false)
        raise 'invalid geometry string' if geometry !~ /^[0-9]+x[0-9]+$/
        if global
          Config.data.set(:geometry, value: geometry)
          Config.save_data
        else
          Config.user_data.set(:geometry, value: geometry)
          Config.save_user_data
        end
      end

      def desktop_type
        type_name =
          user_data.fetch(
            :desktop_type,
            default: data.fetch(
              :desktop_type
            )
          )
        (type_name && Type[type_name] rescue nil) || Type.default
      end

      private
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
  end
end
