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

	# = Manage Server User
	#
	# This class is intended to be used by both the CLI scripts provided, and 3rd party tools
	# written by you! 
	#
	class ServerUser

		def initialize(user_name, dynamo_table = nil, dynamo_primary_key = nil, metadata_label = nil, user_row=nil, metadata_row=nil, server_users=nil)
			@user_name = user_name
			@user_data = {}
			@dirty = false
			@marshaled_columns = [/^TAG__/, /^files$/]

			@dynamo_table = dynamo_table || Env[:dynamo_table]
			@dynamo_primary_key = dynamo_primary_key || Env[:dynamo_primary_key]
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

			if(@user_name == @metadata_label)
				raise "Metadata Label can not be used for a User Name"
			end

			@dynamo = AWS::DynamoDB.new()
			@table = @dynamo.tables[@dynamo_table]
			@table.hash_key = [@dynamo_primary_key.to_sym, :string]
			if(user_row != nil && user_row.attributes[:user_name] == user_name)
				@user_row = user_row
			else
				@user_row = @table.items[@user_name]
			end
			get_user_data(@user_row.attributes)

			if(metadata_row != nil && metadata_row.attributes[:user_name] == @metadata_label)
				@metadata_row = metadata_row
			else
				@metadata_row = @table.items[@metadata_label]
			end

			if(server_users != nil)
				@server_users = server_users
			else
				@server_users = ServerUsers.new(@dynamo_table, @dynamo_primary_key, @metadata_label)
			end

			if(!@user_row.exists?())
				init_user()
			end
		end

		def user_name()
			return @user_name
		end

		def files()
			return @user_data['files']
		end

		def remove_file(file_name)
			@user_data['files'].delete(file_name)
			@dirty = true
		end

		def add_file_path(local_path, remote_path, file_mode)
			if(!File.readable?(local_path))
				raise "Can Not Read #{local_path}"
			end
			data = File.read(local_path)
			add_file_data(data, remote_path, file_mode)
		end

		def add_file_data(data, remote_path, file_mode)
			s3_path = @server_users.user_file_bucket()
			if(!s3_path)
				raise 'User Files are not enabled. Please re-run --configure'
			end
			s3 = AWS::S3.new()
			bucket = s3.buckets[@server_users.user_file_bucket]
			file_path = "#{@user_name}/#{remote_path.sub(/^\//, '')}"
			bucket.objects[file_path].write(data)
			file_size = bucket.objects[file_path].content_length.to_i
			@user_data['files'][remote_path] = {'s3_path' => file_path, 'mode' => file_mode, 'content_length' => file_size}
			@dirty = true
		end

		def shell()
			return @user_data['shell']
		end

		def shell=(shell)
			@user_data['shell'] = shell
			@dirty = true
		end

		def state()
			return @user_data['state']
		end

		def state=(state)
			@user_data['state'] = (state.upcase.to_s == 'ACTIVE' ? 'ACTIVE' : 'INACTIVE')
			@dirty = true
		end

		def public_key()
			return @user_data['public_key']
		end

		def public_key=(key)
			if(@user_data['public_key'] != key)
				@user_data['public_key'] = key
				@user_data['public_key_expire'] = (Date.today + @server_users.max_key_age).to_s
				@dirty = true
			end
		end

		def public_key_expire()
			return @user_data['public_key_expire']
		end

		def full_name()
			return @user_data['full_name']
		end

		def full_name=(name)
			if(@user_data['full_name'] != name)
				@user_data['full_name'] = name
				@dirty = true
			end
		end

		def user_id()
			return @user_data['user_id']
		end

		def identity()
			return @user_data['identity']
		end

		def remove_access(tag_name, tag_value)
			if(!@metadata_row.attributes[:tags].include?(tag_name))
				raise "User Access Tag Name #{tag_name} Not In [#{@metadata_row.attributes[:tags].to_a.join(', ')}]"
			end
			tag_key_name = "TAG__#{tag_name}"
			if(!@user_data.has_key?(tag_key_name))
				return
			end
			if(!@user_data[tag_key_name].has_key?(tag_value))
				return
			end
			@user_data[tag_key_name].delete(tag_value)
			@dirty = true
		end

		def add_access(tag_name, tag_value, sudo)
			if(!@metadata_row.attributes[:tags].include?(tag_name))
				raise "User Access Tag Name #{tag_name} Not In [#{@metadata_row.attributes[:tags].to_a.join(', ')}]"
			end
			tag_key_name = "TAG__#{tag_name}"
			if(!@user_data.has_key?(tag_key_name))
				@user_data[tag_key_name] = {}
			end
			value_data = {'sudo' => sudo != nil}
			if(@user_data[tag_key_name][tag_value] != value_data)
				@user_data[tag_key_name][tag_value] = value_data
				@dirty = true
			end
		end

		def save()
			if(!@dirty)
				return
			end
			@user_row.attributes.update do |u|
				@user_data.each_pair do |key,value|
					if(key != 'user_name' && key != 'identity')
						if(value == nil)
							u.delete(key)
						else
							marshal = false
							@marshaled_columns.each do |regex|
								if(key.match(regex))
									marshal = true
									break
								end
							end
							if(marshal)
								value = value.to_json.force_encoding('UTF-8')
							end
							u.set(key => value)
						end
					end
				end
				if(!@user_data['user_id'])
					user_id = @metadata_row.attributes.add({:next_uid => 1}, :return => :updated_old)
					u.set(:user_id => user_id['next_uid'])
				end
				u.add(:identity => 1)
			end
			@metadata_row.attributes.add(:identity => 1)
			@dirty = false
		end

		def display()
			puts "Full Name: ".green()+"#{@user_data['full_name']}".light_blue
			puts "UserName: ".green()+"#{@user_name}".light_blue
			puts "State: ".green()+"#{@user_data['state']}".send(@user_data['state'] == 'ACTIVE' ? :light_blue : :red)
			puts "Key Expire: ".green()+"#{@user_data['public_key_expire']}".light_blue
			puts "Shell: ".green()+"#{@user_data['shell']}".light_blue
			puts
			puts "User Access".green
			access_tags.each_pair do |tag_name, tag_data|
				tag_data.each_pair do |tag_value, server_data|
					puts "  #{tag_name}".green+" => ".light_white+"#{tag_value}".send(server_data['sudo'] ? :red : :light_cyan)
				end
			end
			puts
			puts "Files".green
			@user_data['files'].each_pair do |remote_path, file_data|
				puts "  ~/#{remote_path}".light_cyan+" (#{file_data['content_length']})".yellow
			end
			puts
		end

		def access_tags()
			tag_columns = {}
			@user_data.each_pair do |key, value|
				key.match(/^TAG__(.*)/) do |match|
					tag_columns[match[1]] = value
				end
			end
			return tag_columns
		end

		private

		def init_user()
			@user_data['type'] = 'USER'
			@user_data['shell'] = '/bin/bash'
			@user_data['state'] = 'ACTIVE'
			@user_data['files'] = {}
			@user_data['identity'] = 0
			@dirty = true
		end

		def get_user_data(attributes)
			attributes.to_h.each_pair do |key, value|
				marshaled = false
				@marshaled_columns.each do |regex|
					if(key.match(regex))
						marshaled = true
						break
					end
				end
				if(marshaled)
					value = JSON.load(value)
				end
				@user_data[key] = value
			end
		end

	end
end
