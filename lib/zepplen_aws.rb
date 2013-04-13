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


require 'yaml'
require 'colorize'
require 'zepplen_aws/env'

# The goal of ZepplenAWS is to provide useful tools for maintaining Linux instances in AWS.
# Development and testing is currently being done on Ubuntu instances, however they should on any
# flavor of *nix.
#
# = Zepplen Users
# Required zepplen_users_admin Permissions
#	1. DynamoDB
#   * dynamodb:BatchGetItem
#		* dynamodb:DeleteItem
#		* dynamodb:DescribeTable
#		* dynamodb:GetItem
#		* dynamodb:PutItem
#		* dynamodb:Query
#		* dynamodb:UpdateItem
#	2. EC2
#		* ec2:DescribeInstances
#		* ec2:DescribeTags
#	3. S3 (optional)
#		* s3:GetObject
#		* s3:PutObject
#		* s3:DeleteObject
#
# Required zepplen_users Permissions
#	1. DynamoDB
#   * dynamodb:BatchGetItem
#		* dynamodb:DescribeTable
#		* dynamodb:GetItem
#		* dynamodb:Query
#	2. EC2
#		* ec2:DescribeInstances
#		* ec2:DescribeTags
#	3. S3 (optional)
#		* s3:GetObject
#
# Required zepplen_dns Permissions
#	1. EC2
#		* ec2:DescribeInstances
#		* ec2:DescribeTags
# 2. Elastic Load Ballancing
#		* elasticloadbalancing:DescribeLoadBalancers
#	3. Route53
#		* route53:ChangeResourceRecordSets
#   * route53:GetHostedZone
#   * route53:ListHostedZones
#   * route53:ListResourceRecordSets

module ZepplenAWS
	autoload :AWS, 'zepplen_aws/aws'
	autoload :AutoDNS, 'zepplen_aws/auto_dns'
	autoload :ServerUsers, 'zepplen_aws/server_users'
	autoload :ServerLocalUsers, 'zepplen_aws/server_local_users'
	autoload :ServerUser, 'zepplen_aws/server_user'
	autoload :Exceptions, 'zepplen_aws/exceptions'
end

ZepplenAWS::Env.init!
