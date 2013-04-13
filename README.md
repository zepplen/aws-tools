aws-tools
=========

#Ruby AWS tools for common tasks

##Ubuntu/Debian Install
You will need the following apt-get packages to install all the required gems:
1. ruby1.9.1-dev
2. build-essential
3. libxml2-dev
4. libxslt1-dev

##Tools
1. Automatic Route53 DNS Creation: zepplen_dns
2. Centralized User Management: zepplen_users, zepplen_users_admin

The goal of ZepplenAWS is to provide useful tools for maintaining Linux instances in AWS.
Development and testing is currently being done on Ubuntu instances, however they should on any
flavor of *nix.

##Zepplen Users
Required zepplen_users_admin Permissions
1. DynamoDB
  * dynamodb:BatchGetItem
  * dynamodb:DeleteItem
  * dynamodb:DescribeTable
  * dynamodb:GetItem
  * dynamodb:PutItem
  * dynamodb:Query
  * dynamodb:UpdateItem
2. EC2
  * ec2:DescribeInstances
  * ec2:DescribeTags
3. S3 (optional)
  * s3:GetObject
  * s3:PutObject
  * s3:DeleteObject

Required zepplen_users Permissions
1. DynamoDB
  * dynamodb:BatchGetItem
  * dynamodb:DescribeTable
  * dynamodb:GetItem
  * dynamodb:Query
2. EC2
  * ec2:DescribeInstances
  * ec2:DescribeTags
3. S3 (optional)
  * s3:GetObject

Required zepplen_dns Permissions
1. EC2
  * ec2:DescribeInstances
  * ec2:DescribeTags
2. Elastic Load Ballancing
  * elasticloadbalancing:DescribeLoadBalancers
3. Route53
  * route53:ChangeResourceRecordSets
  * route53:GetHostedZone
  * route53:ListHostedZones
  * route53:ListResourceRecordSets

