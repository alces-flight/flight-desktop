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

module Desktop
  module Config
    class << self
      DESKTOP_DIR_SUFFIX = File.join('flight','desktop')

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

      def path
        config_path_provider.path ||
          config_path_provider.paths.first
      end

      def root
        @root ||= File.expand_path(File.join(__dir__, '..', '..'))
      end

      def session_path
        @session_path ||= File.join(xdg_cache.home, DESKTOP_DIR_SUFFIX, 'sessions')
      end

      def user_verify_path
        @user_verify_path ||= File.join(xdg_data.home, DESKTOP_DIR_SUFFIX, 'types')
      end

      def vnc_passwd_program
        @vnc_passwd_program ||=
          data.fetch(
            :vnc_passwd_program,
            default: '/usr/bin/vncpasswd'
          )
      end

      def vnc_server_program
        @vnc_server_program ||=
          File.expand_path(
            data.fetch(
              :vnc_passwd_program,
              default: File.join('libexec','vncserver')
            ),
            Config.root
          )
      end

      def functional?
        File.executable?(vnc_passwd_program) &&
          File.executable?(vnc_server_program)
      end

      def type_paths
        @type_paths ||=
          data.fetch(
            :type_paths,
            default: [
              'etc/types'
            ]
          ).map {|p| File.expand_path(p, Config.root)}
      end

      def access_hosts
        data.fetch(
          :access_hosts,
          default: []
        )
      end

      def access_ip
        data.fetch(
          :access_ip,
          default: NetworkUtils.primary_ip
        )
      end

      def access_host
        data.fetch(
          :access_host,
          default: access_ip
        )
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

      def bg_image
        data.fetch(:bg_image)
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
