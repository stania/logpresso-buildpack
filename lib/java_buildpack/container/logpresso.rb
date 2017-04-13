# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/component/base_component'
require 'java_buildpack/container'
require 'java_buildpack/util/dash_case'
require 'java_buildpack/util/java_main_utils'
require 'java_buildpack/util/qualify_path'
require 'java_buildpack/util/spring_boot_utils'

module JavaBuildpack
  module Container

    # Encapsulates the detect, compile, and release functionality for applications running a simple Java +main()+
    # method. This isn't a _container_ in the traditional sense, but contains the functionality to manage the lifecycle
    # of Java +main()+ applications.
    class Logpresso < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      # Creates an instance
      #
      # @param [Hash] context a collection of utilities used the component
      def initialize(context)
        super(context)
        @spring_boot_utils = JavaBuildpack::Util::SpringBootUtils.new
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        #main_class ? JavaMain.to_s.dash_case : nil
        check_logpresso_package ? Logpresso.to_s.dash_case : nil
      end

      def check_logpresso_package
        core_found = false
        cache_found = false
        @core_name = nil
        Dir["#{@application.root}/*"].each do | file |
          if !core_found && (File.basename(file).start_with? 'araqne-core') then
            core_found = true
            @core_name = File.basename(file)
          end
          if !cache_found && File.basename(file) == 'cache' && File.directory?(file) then cache_found = true end
          break if core_found && cache_found
        end
        core_found && cache_found
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        ## java is already unpacked in ./.java_buildpack/open_jdk_jre
        puts '-----> Araqne-Core found: ' + @core_name
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        release_text
      end

      def release_text
        @config = @configuration['logpresso'].reduce({}, :merge)
        [
          "exec",
          "#{qualify_path @droplet.java_home.root, @droplet.root}/bin/java", 
          "-DINSTANCE_ID=#{@config['INSTANCE_ID'].to_s}",
          "-Dipojo.proxy=disabled",
          "-Daraqne.ssh.timeout=0",
          "-Dlogpresso.sentry.disableFlowControl=true",
          "-Daraqne.logdb.cepengine=redis",
          "-Dlogpresso.httpd.port=$PORT",
          "-XX:+UseG1GC",
          "-XX:MaxGCPauseMillis=100",
          "-XX:GCPauseIntervalMillis=1000",
          "-XX:StringTableSize=1000003",
          "-XX:+PrintGCDateStamps",
          "-Xloggc:log/gc.log",
          "-XX:+UseGCLogFileRotation",
          "-XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=10240K",
          "$JAVA_OPTS",
          "-Xmx#{@config["HEAP_MAX"].to_s}",
          "-XX:MaxDirectMemorySize=#{@config["DIRECTMEMORY_MAX"].to_s}",
          "-jar #{qualify_path @droplet.root, @droplet.root}/#{@core_name}"
        ].flatten.compact.join(' ')

      private

      ARGUMENTS_PROPERTY = 'arguments'.freeze

      CLASS_PATH_PROPERTY = 'Class-Path'.freeze

      private_constant :ARGUMENTS_PROPERTY, :CLASS_PATH_PROPERTY

      def arguments
        @configuration[ARGUMENTS_PROPERTY]
      end

      def main_class
        JavaBuildpack::Util::JavaMainUtils.main_class(@application, @configuration)
      end

      def manifest_class_path
        values = JavaBuildpack::Util::JavaMainUtils.manifest(@application)[CLASS_PATH_PROPERTY]
        values.nil? ? [] : values.split(' ').map { |value| @droplet.root + value }
      end

    end

  end
end

# vim: ts=2 sw=2: expandtab
