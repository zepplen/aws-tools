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

module ZepplenAWS
	autoload :AWS, 'zepplen_aws/aws'
	autoload :AutoDNS, 'zepplen_aws/auto_dns'
end

ZepplenAWS::Env.init!
