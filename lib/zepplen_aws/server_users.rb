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

	# = Manage Server Users
	#
	# This class is intended to be used by both the CLI scripts provided, and 3rd party tools
	# written by you! 
	#
	class ServerUsers

		def initialize(dynamo_table = nil, dynamo_primary_key = nil, metadata_label = nil)
			@dynamo_table = dynamo_table || Env[:dynamo_table]
			@dynamo_primary_key = dynamo_primary_key || Env[:dynamo_primary_key]
			@dynamo_primary_key = @dynamo_primary_key.to_sym
			@metadata_label = metadata_label || Env[:metadata_label]

			if(@dynamo_table == nil)
				raise "DynamoDB Table Name Required"
			end

			if(@dynamo_primary_key == nil)
				raise "DynamoDB Table Hash Key Required"
			end

			if(@metadata_label == nil)
				raise "DynamoDB Metadata Label Required"
			end

			@dynamo = AWS::DynamoDB.new()
			@table = @dynamo.tables[@dynamo_table]
			@table.hash_key = [@dynamo_primary_key, :string]
			@metadata = @table.items[@metadata_label]

			@local_user_data = {}
		end

		def update_from_dynamo(local_users = nil)
			if(!local_users)
				local_users = Env[:local_users]
			end
			if(!update_required?(local_users))
				return
			end
			@table.items.where(:type => 'USER').each do |row|
			end
		end

		def identity()
			return @metadata.attributes[:identity]
		end

		def user_file_bucket()
			return @metadata.attributes[:user_file_bucket]
		end

		def user_file_bucket=(s3_path)
			update_metadata(:user_file_bucket => s3_path)
			return nil
		end

		def max_key_age()
			return @metadata.attributes[:max_key_age]
		end

		def max_key_age=(key_age)
			update_metadata(:key_age => key_age)
			return nil
		end

		def next_uid()
			return @metadata.attributes[:next_uid]
		end

		def next_uid=(next_uid)
			update_metadata(:next_uid => next_uid)
			return nil
		end

		def sudo_group()
			return @metadata.attributes[:sudo_group]
		end

		def sudo_group=(sudo_group)
			update_metadata(:sudo_group => sudo_group)
			return nil
		end

		def tags()
			return @metadata.attributes[:tags]
		end

		def tags=(tags)
			update_metadata(:tags => tags)
			@metadata.attributes.update do |u|
				u.set(:tags => tags)
				u.add(:idenity => 1)
			end
			return nil
		end

		def add_tags(tags)
			@metadata.attributes.update do |u|
				u.add(:tags => tags)
				u.add(:idenity => 1)
			end
			return nil
		end

		def remove_tags(tags)
			@metadata.attributes.update do |u|
				u.delete(:tags => tags)
				u.add(:idenity => 1)
			end
			return nil
		end

		def user_file_bucket()
			return @metadata.attributes[:user_file_bucket]
		end

		def user_file_bucket=(s3_path)
			update_metadata(:user_file_bucket => s3_path)
			return nil
		end

		def configure(config)
			valid_configs = [:next_uid, :max_key_age, :tags, :sudo_group]
			to_use_config = config.select{|k,v| valid_configs.include?(k)}
			@metadata.attributes.update do |item_data|
				item_data.set(:type => 'METADATA')
				item_data.set(to_use_config)
				if(config.has_key?(:user_file_bucket))
					if(config[:user_file_bucket])
						item_data.set(:user_file_bucket => config[:user_file_bucket])
					else
						item_data.delete(:user_file_bucket)
					end
				end
				if(@metadata.attributes[:identity] == nil)
					item_data.set(:identity => 0)
				end
			end
		end

		def users()
			users = {}
			@table.items.where(:type => 'USER').each do |user_row|
				users[user_row.attributes[@dynamo_primary_key]] = ServerUser.new(user_row.attributes[@dynamo_primary_key], nil, nil, nil, user_row, @metadata)
			end
			return users
		end

		private

		def update_metadata(data)
			@metadata.attributes.update do |u|
				data.each_pair do |key, value|
					if(value)
						u.set(key => value)
					else
						u.delete(key)
					end
				end
				u.add(:identity => 1)
			end
		end

		def update_required?(local_users)
			if(!File.readable?(local_users))
				return true
			end
			@local_user_data = Yaml.load(local_users)
		end

	end
end
