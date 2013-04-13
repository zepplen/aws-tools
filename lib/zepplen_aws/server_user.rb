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

		# = ServerUser
		# If you are using the default DynamoDB table name 'users' only user_name is required to create
		# a ServerUser object. If you have deviated from this standard you must pass dynamo_table name in
		# as either a paramater, or via the Env class.
		#
		#	@param [String] User Name
		# @param optional [String] Name of DynamoDB to read settings and users from
		# @param optional [AWS::DynamoDB::Item] DynamoDB Item reflecting the requested user (used to prevent multiple DB Hits)
		# @param optional [AWS::DynamoDB::Item] DynamoDB Item reflecting the metadata setings (used to prevent multiple DB Hits)
		# @param optional [ZepplenAWS::ServerUsers] ServerUsers object (used to prevent multiple DB Hits)
		def initialize(user_name, dynamo_table = nil, user_row=nil, metadata_row=nil, server_users=nil)
			@user_name = user_name
			@user_data = {}
			@remove_s3_files = []
			@dirty = false
			@marshaled_columns = [/^TAG__/, /^files$/]

			@dynamo_table = dynamo_table || Env[:dynamo_table] || 'users'

			if(@dynamo_table == nil)
				raise Exceptions::Users::MissingOption, "DynamoDB Table Name Required"
			end

			@dynamo = AWS::DynamoDB.new()
			@table = @dynamo.tables[@dynamo_table]
			@table.hash_key = {:type => :string}
			@table.range_key = {:user_name => :string}
			if(user_row != nil && user_row.attributes[:user_name] == user_name)
				@user_row = user_row
			else
				@user_row = @table.items['USER', @user_name]
			end
			get_user_data(@user_row.attributes)

			if(metadata_row != nil && metadata_row.attributes[:user_name] == @metadata_label)
				@metadata_row = metadata_row
			else
				@metadata_row = @table.items['METADATA', '__metadata__']
			end

			if(server_users != nil)
				@server_users = server_users
			else
				@server_users = ServerUsers.new(@dynamo_table)
			end

			if(!@user_row.exists?())
				init_user()
			end
		end

		# User Name
		#
		# @return [String]
		def user_name()
			return @user_name
		end

		# Hash of files associated with user's profile
		#
		# @return [Hash]
		def files()
			return @user_data['files']
		end

		# Remove file from user's profile
		#
		# Note: the file will be removed from S3 Before object is saved!
		#
		# @param [String] Remote file location of file to remove
		def remove_file(file_name)
			if(@user_data['files'].has_key?(file_name))
				s3 = AWS::S3.new()
				bucket = s3.buckets[@server_users.user_file_bucket]
				bucket.objects[@user_data['files'][file_name]['s3_path']].delete()
				@user_data['files'].delete(file_name)
			end
			@dirty = true
			return nil
		end

		# Add File Path
		#
		# Note: This will add the file to S3 Before the object is saved!
		#
		# @param [String] Location of file to add
		# @param [String] Destination in the user's home dir to place file on remove servers
		# @param [String] Linux file mode (eg: '600')
		def add_file_path(local_path, remote_path, file_mode)
			if(!File.readable?(local_path))
				raise "Can Not Read #{local_path}"
			end
			data = File.read(local_path)
			add_file_data(data, remote_path, file_mode)
			return nil
		end

		# Add File Path
		#
		# Note: This will add the file to S3 Before the object is saved!
		#
		# @param [String] File data
		# @param [String] Destination in the user's home dir to place file on remove servers
		# @param [String] Linux file mode (eg: '600')
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
			return nil
		end

		# Shell
		#
		# @return [String] User's shell
		def shell()
			return @user_data['shell']
		end

		# Set Shell
		#
		# @param [String] Set user's shell. (Default: /bin/bash)
		def shell=(shell)
			@user_data['shell'] = shell
			@dirty = true
			return nil
		end

		# User State
		#
		# @return [String] User State (ACTIVE/INACTIVE)
		def state()
			return @user_data['state']
		end

		# Set User State
		#
		# @param [String/Symbol] User State (ACTIVE/INACTIVE)
		def state=(state)
			@user_data['state'] = (state.upcase.to_s == 'ACTIVE' ? 'ACTIVE' : 'INACTIVE')
			@dirty = true
			return nil
		end

		# Public Key
		#
		# @return [String] SSH Public Key
		def public_key()
			return @user_data['public_key']
		end

		# Set Public Key
		#
		# Setting the public key also sets the public_key_expire date.
		#
		# @param [String] SSH Public Key
		def public_key=(key)
			if(@user_data['public_key'] != key)
				@user_data['public_key'] = key
				@user_data['public_key_expire'] = (Date.today + @server_users.max_key_age).to_s
				@dirty = true
			end
			return nil
		end

		# Public Key Expire Date
		#
		#	This is only set when the public_key value is set
		#
		# @return [String] Public Key Expire Date (String)
		def public_key_expire()
			return @user_data['public_key_expire']
		end

		# Full Name
		#
		# @return [String] User's full name
		def full_name()
			return @user_data['full_name']
		end

		# Set Full Name
		#
		# @param [String] User's full name
		def full_name=(name)
			if(@user_data['full_name'] != name)
				@user_data['full_name'] = name
				@dirty = true
			end
			return nil
		end

		# User ID
		#
		# Linux User ID (set automaticaly at user creation)
		#
		# @return [Integer] Linux user id
		def user_id()
			return @user_data['user_id']
		end

		# Identity
		#
		# Used to identify if the user entry has changed. Incremented on each write to DynamoDB for this user.
		#
		# @return [Integer] Identity
		def identity()
			return @user_data['identity']
		end

		# Remove Access
		#
		# Remove's a users access from a Tag Name => Tag Value combination
		#
		# @param [String] EC2 Tag Name to target (Case Sensitive)
		# @param [String] EC2 Tag Value to target (Case Sensitive)
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
			return nil
		end

		# Add Access
		#
		# Users are targeted to a server by EC2 Tags. The list of valid tags is listed at the environmen level.
		# run --configure to change the list of valid tags
		#
		# @param [String] EC2 Tag Name
		# @param [String] EC2 Tag Value
		# @param [Object] Grant Sudo access. (nil: no sudo, not_nil: sudo access)
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
			return nil
		end

		# Save
		#
		# This call will only write to Dynamo if a change has been made.
		# When we update the row we also update the identity of the row. This will allows us to save
		# calls to Dynamo/S3 when we write the users to the remote servers
		def save()
			if(!@dirty)
				return
			end
			@user_row.attributes.update do |u|
				@user_data.each_pair do |key,value|
					if(key != 'user_name' && key != 'identity' && key != 'type')
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
			return nil
		end

		# Display User
		#
		# Prints the user's profile to the screen with console colors enabled
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
			return nil
		end

		# Access Tags
		#
		# Returns a list of the EC2 Tags user has associated to their profile
		#
		# @return [Hash] EC2 Tag names and their values to match on
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
