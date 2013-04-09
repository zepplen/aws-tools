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
	module AWS
		class InstanceData

			def initialize(address=nil, base_path=nil)
				if(base_path)
					@base_path = base_path
				else
					@base_path = '/latest/meta-data/'
				end
				if(address)
					@address = address
				else
					@address = '169.254.169.254'
				end
				@net = Net::HTTP.new('169.254.169.254')
				@values = []
				@dirs = []
				response = @net.get(@base_path)
				response.body.split("\n").each do |line|
					line.chomp.match(/^([^\/]*)(\/?)$/) do |match|
						if(match[2] != '')
							@dirs << match[1]
						else
							@values << match[1]
						end
					end
				end
			end

			def to_s()
				return list.to_yaml
			end

			def dirs()
				return @dirs
			end

			def values()
				return @values
			end

			def list()
				to_return = []
				to_return = @dirs.map{|item| "#{item}/"}
				to_return += @values
				return to_return
			end

			def [](key)
				if(@dirs.include?(key))
					return InstanceData.new(@address, "#{@base_path}#{key}/")
				end
				if(@values.include?(key))
					return @net.get("#{@base_path}#{key}/").body.chomp
				end
				return nil
			end

		end
	end
end
