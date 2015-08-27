# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014-2015 the original author or authors.
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
require 'liberty_buildpack/diagnostics/common'
require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/framework'
require 'liberty_buildpack/framework/framework_utils'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/download'
require 'liberty_buildpack/util/tokenized_version'
require 'liberty_buildpack/container/common_paths'
require 'liberty_buildpack/services/vcap_services'
require 'pathname'
require 'fileutils'

module LibertyBuildpack::Framework

  # Encapsulates the detection, compile, and release functionality for DynamicPULSE Agent
  class DynamicPULSEAgent

    # An initializer for the instance.
    #
    # @param [Hash<Symbol, String>] context A shared context provided to all components
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Hash] :environment A hash containing all environment variables except +VCAP_APPLICATION+ and
    #                                     +VCAP_SERVICES+.  Those values are available separately in parsed form.
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    # @option context [String] :lib_directory the directory that additional libraries are placed in
    def initialize(context = {})
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @environment = context[:environment]
      @java_opts = context[:java_opts]
      @lib_directory = context[:lib_directory]
    end

    DP_URL = 'DP_URL'.freeze

    # Detects whether DynamicPULSE Agent can attach
    #
    # @return [String, nil] returns +DynamicPULSE+ if DynamicPULSE Agent can attach otherwise returns +nil+
    def detect
      return 'DynamicPULSE' if @environment.has_key?(DP_URL)
      nil
    end

    # Downloads and places the DynamicPULSE JARs
    #
    # @return [void]
    def compile
      dp_url = @environment[DP_URL]
      dp_home = File.join(@app_dir, ".dynamic_pulse_agent")
      FileUtils.mkdir_p(dp_home)

      download_jar(dp_url, "dynamicpulse.jar", @lib_directory)
      download_jar(dp_url, "aspectjweaver.jar", dp_home)

      FrameworkUtils.link_libs([@app_dir], @lib_directory)
    end

    # Append VM options to java_opts
    #
    # @return [void]
    def release
      @java_opts << "-javaagent:/home/vcap/app/.dynamic_pulse_agent/aspectjweaver.jar"
      @java_opts << "-Dorg.aspectj.tracing.factory=default"
    end

    # Downloads a JAR file from specified url
    def download_jar(dp_url, basename, save_to_dir)
      version = LibertyBuildpack::Util::TokenizedVersion.new("1.+")
      begin
        LibertyBuildpack::Util.download(version, dp_url + basename, "download jar", basename, save_to_dir)
      rescue
        @logger.error("[DynamicPULSE] Can't download #{basename} from #{dp_url}. Please check your DP_URL environment variable.");
        raise
      end
    end
  end
end

