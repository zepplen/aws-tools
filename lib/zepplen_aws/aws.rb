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

	# Wrapper module for the aws-sdk Gem
	#
	# This module enables pasing authentication from the ENV to the AWS Libs.
	# It also acts as a (very small) layer of abstraction between the 3rd party lib
	# and our code.
	module AWS
		require 'aws-sdk'

		autoload :EC2, 'zepplen_aws/aws/ec2'
		autoload :S3, 'zepplen_aws/aws/s3'
		autoload :ELB, 'zepplen_aws/aws/elb'
		autoload :Route53, 'zepplen_aws/aws/route53'
		autoload :DynamoDB, 'zepplen_aws/aws/dynamo_db'
		autoload :InstanceData, 'zepplen_aws/aws/instance_data'

		# Sets the AWS Configuration from the Env class.
		def self.init!()
			::AWS.config(:access_key_id => Env.options[:aws_access_key_id], :secret_access_key => Env.options[:aws_secret_access_key])
		end

	end
end

ZepplenAWS::AWS.init!
