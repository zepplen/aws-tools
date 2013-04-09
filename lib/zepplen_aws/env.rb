#Copyright 2013 Mark Trimmer
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

module ZepplenAWS

	# = Manage Environment
	#
	# This is a utility class used by the code to manage bassic nessisities of the Environment.
	#
	# == Options
	#
	# This class will automatically load parameters from multiple sources. AWS Keys are attempted
	# to be retrieved from Environmental Variables (AWS_ACCESS_KEY, AWS_SECRET_ACCESS_KEY).
	# We can also load configuration from a YAML file. Our first attempt to locate a config file
	# is by making use of the AWS_CONFIG_FILE Environmental Variable. If the varialbe points to a
	# readable file, we will load configs from that. Beyond that we try to load configs from the
	# following locations in order:
	# 1. $HOME/.zepplen_aws.yaml
	# 2. /etc/zepplen_aws/config.yaml
	#
	# If options are passed to us from another source
	#   ZepplenAWS::Env.options = options
	# these options will override any configuration pulled from the ENV or config files.
	#
	# To use AWS IAM Roles for authentication, leave the :aws_access_key_id and :aws_secret_access_key
	# parameter empty.
	class Env

		# Allows user to inject options into the Environment
		#
		# @example Injecting Options With a Hash
		#   ZepplenAWS::Env.options = options
		#
		# @param [Hash] options Options to inject into Environment
		def self.options=(options)
			if(options.has_key?(:config_file) && options[:config_file])
				load_yaml(options[:config_file])
			end
			@options.merge!(options) do |key, old, new|
				new == nil ? old : new
			end
			return nil
		end

		# Allows user to retrive the current option set
		#
		# @return [Hash] Current Options
		def self.options()
			return @options
		end

		# Allows user access to single option
		#
		# @param [Object] Key to retrieve
		#
		# @return [Object] Request option
		def self.[](key)
			return @options[key]
		end

		# Allow user access to set single option
		#
		# @param [Object] option key
		# @param [Object] option value
		def self.[]=(key, value)
			@options[key] = value
		end


		# Not intented for general use
		#
		# This function initializes the Env class, and will be called automatically uppon gem inclusion
		def self.init!()
			@options = {}
			if(ENV.has_key?('AWS_ACCESS_KEY'))
				@options[:aws_access_key_id] = ENV['AWS_ACCESS_KEY']
			end
			if(ENV.has_key?('AWS_SECRET_ACCESS_KEY'))
				@options[:aws_secret_access_key] = ENV['AWS_SECRET_ACCESS_KEY']
			end
			if(ENV.has_key?('AWS_CONFIG_FILE') && File.readable?(ENV['AWS_CONFIG_FILE']))
				load_yaml(ENV['AWS_CONFIG_FILE'])
			elsif(File.readable?("#{ENV['HOME']}/.zepplen_aws.yaml"))
				load_yaml("#{ENV['HOME']}/.zepplen_aws.yaml")
			elsif(File.readable?('/etc/zepplen_aws/config.yaml'))
				load_yaml('/etc/zepplen_aws/config.yaml')
			end
		end

		# Not intended for general use
		#
		# This function import configuration from a YAML file
		def self.load_yaml(file)
			if(!File.readable?(file))
				raise "Config File UnReadable: #{file}"
			end
			options = YAML::load_file(file)
			@options.merge!(options) do |key, old, new|
				new == nil ? old : new
			end
		end

	end
end
