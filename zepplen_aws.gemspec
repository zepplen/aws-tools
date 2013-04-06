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

Gem::Specification.new do |s|
	s.name = 'zepplen_aws'
	s.version = '0.0.1'
	s.date = '2013-04-05'
	s.summary = 'Aws Toolset'
	s.description = 'AWS tools for common needs'
	s.authors = ["Mark Trimmer"]
	s.add_runtime_dependency "aws-sdk", ["> 1.8.0"]
	s.add_runtime_dependency "colorize", [">= 0.5.8"]
end
