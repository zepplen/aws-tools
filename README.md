aws-tools
=========

#Ruby AWS tools for common tasks

##Ubuntu/Debian Install
You will need the following apt-get packages to install all the required gems:
* ruby1.9.1-dev
* build-essential
* libxml2-dev
* libxslt1-dev

##Tools
* Automatic Route53 DNS Creation: zepplen_dns
* Centralized User Management: zepplen_users, zepplen_users_admin

The goal of ZepplenAWS is to provide useful tools for maintaining Linux instances in AWS.
Development and testing is currently being done on Ubuntu instances, however they should on any
flavor of *nix.

##Zepplen Users
Required zepplen_users_admin Permissions
* DynamoDB
  * dynamodb:BatchGetItem
  * dynamodb:DeleteItem
  * dynamodb:DescribeTable
  * dynamodb:GetItem
  * dynamodb:PutItem
  * dynamodb:Query
  * dynamodb:UpdateItem
* EC2
  * ec2:DescribeInstances
  * ec2:DescribeTags
* S3 (optional)
  * s3:GetObject
  * s3:PutObject
  * s3:DeleteObject

Required zepplen_users Permissions
* DynamoDB
  * dynamodb:BatchGetItem
  * dynamodb:DescribeTable
  * dynamodb:GetItem
  * dynamodb:Query
* EC2
  * ec2:DescribeInstances
  * ec2:DescribeTags
* S3 (optional)
  * s3:GetObject

Required zepplen_dns Permissions
* EC2
  * ec2:DescribeInstances
  * ec2:DescribeTags
* Elastic Load Ballancing
  * elasticloadbalancing:DescribeLoadBalancers
* Route53
  * route53:ChangeResourceRecordSets
  * route53:GetHostedZone
  * route53:ListHostedZones
  * route53:ListResourceRecordSets

