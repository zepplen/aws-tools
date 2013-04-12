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
	class ServerLocalUsers
	require 'etc'

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

			@server_users = ServerUsers.new(@dynamo_table, @dynamo_primary_key, @metadata_label)

			@dynamo = AWS::DynamoDB.new()
			@table = @dynamo.tables[@dynamo_table]
			@table.hash_key = [@dynamo_primary_key, :string]
			@metadata = @table.items[@metadata_label]

			@instance_data = AWS::InstanceData.new
			@tags = {}
			load_instance_tags()
			@local_user_data = {}
			@local_user_data[:local_users] = {}

			@local_user_file = '/etc/zepplen_aws/local_users.yaml'
		end

		def local_user_file()
			return @local_user_file
		end

		def local_user_file=(user_file)
			@local_user_file = user_file
		end

		def update!(commit)
			dynamo_users = load_metadata_from_dynamo()
			local_users = load_from_file()
			static_updates = {}
			if(local_users.has_key?(:metadata) && local_users[:metadata].has_key?(:identity) && local_users[:metadata][:identity] == dynamo_users[:metadata][:identity])
				users = local_users
				users[:local_users].each_pair do |user_name, user_data|
					static_updates[user_name] = false
				end
			else
				users = load_users_from_dynamo(dynamo_users)
				users[:local_users].each_pair do |user_name, user_data|
					if(local_users[:local_users].has_key?(user_name) && local_users[:local_users][user_name][:identity] == users[:local_users][user_name][:identity])
						static_updates[user_name] = false
					else
						static_updates[user_name] = true
					end
				end
			end
			make_server_users(users, static_updates)
		end

		private

		def make_server_users(users, static_update)
			#TODO: Write Linux User Admin Object
			begin
				# Yes, we could probably just assume 0, but this seemed safer
				etc_user = Etc.getpwnam('root')
				root_uid = etc_user['uid']
			rescue ArgumentError
				raise "Can Not Find Root User!!!"
			end
			users[:local_users].each_pair do |user_name, user_data|
				begin
					etc_user = Etc.getpwnam(user_name)
				rescue ArgumentError
					system "useradd -d /home/#{user_name} -c \"#{user_data[:full_name]}\" -m -s #{user_data[:shell]} -u #{user_data[:user_id]} -U #{user_name}"
				end
				user_gid = Etc.getgrnam(user_name)['gid']
				if(user_data[:sudo])
					system "usermod -a -G #{users[:metadata][:sudo_group]} #{user_name}"
				else
					system "usermod -G #{user_name} #{user_name}"
				end
				if(!File.exist?("/home/#{user_name}/.ssh"))
					system "mkdir /home/#{user_name}/.ssh"
					system "chmod 700 /home/#{user_name}/.ssh"
					system "chown #{user_name}:#{user_name} /home/#{user_name}/.ssh"
				end
				if(Date.parse(user_data[:public_key_expire]) > Date.today)
					write_local_file("/home/#{user_name}/.ssh/authorized_keys", '640', user_data[:public_key], root_uid, user_gid)
				else
					write_local_file("/home/#{user_name}/.ssh/authorized_keys", '640', 'Revoked', user_data[:user_id], user_gid)
				end
				if(static_update[user_name] && user_data[:files])
					s3 = AWS::S3.new()
					bucket = s3.buckets[users[:metadata][:user_file_bucket]]
					user_data[:files].each_pair do |file_name, file_data|
						s3object = bucket.objects[file_data['s3_path']]
						write_local_file("/home/#{user_name}/#{file_name}", file_data['mode'], s3object.read, user_data[:user_id], user_gid)
					end
				else
				end
			end
		end

		def write_local_file(path, mode, contents, user_id, group_id)
			begin
				mode = mode.to_i(8)
				if(!Dir.exist?(File.dirname(path)))
					system "mkdir -p #{File.dirname(path)}"
				end
				fout = File.open(path, 'w')
				fout.chmod(mode)
				fout.chown(user_id, group_id)
				fout.write(contents)
				fout.close
			rescue => e
				puts e
			end
		end

		def load_users_from_dynamo(users)
			@table.items.where(:type => 'USER').where(:state => 'ACTIVE').each do |row|
				user = ServerUser.new(row.attributes[:user_name], @dynamo_table, @dynamo_primary_key, @metadata_label, row)
				@tags.each_pair do |instance_tag, instance_value|
					if(user.access_tags.has_key?(instance_tag) && user.access_tags[instance_tag].has_key?(instance_value))
						add_user(user, instance_tag, instance_value, users)
					end
				end
			end
			save_to_file(users)
			return users
		end

		def load_metadata_from_dynamo()
			metadata = @table.items[@metadata_label]
			users = {}
			users[:metadata] = {}
			users[:local_users] = {}
			users[:metadata][:identity] = metadata.attributes['identity'].to_i
			users[:metadata][:max_key_age] = metadata.attributes['max_key_age'].to_i
			users[:metadata][:sudo_group] = metadata.attributes['sudo_group']
			users[:metadata][:user_file_bucket] = metadata.attributes['user_file_bucket']
			return users
		end

		def save_to_file(users)
			folder_name = File.dirname(@local_user_file)
			if(!Dir.exist?(folder_name))
				base_path = '/'
				folder_name.split('/').each do |dir|
					if(dir != '')
						base_path += "#{dir}/"
puts "Checking #{base_path}"
						if(!Dir.exist?(base_path))
							begin
puts "Making #{base_path}"
								Dir.mkdir(base_path, 0700)
							rescue SystemCallError
								raise "Can not create folder #{base_path}"
							end
						end
					end
				end
			end
			fout = File.open(@local_user_file, 'w')
			fout.write(users.to_yaml)
			fout.chmod(0600)
			fout.close()
			
		end

		def load_from_file()
			if(File.readable?(@local_user_file))
				users = YAML::load_stream(File.open(@local_user_file))[0]
			else
				users = {}
				users[:local_users] = {}
			end
			return users
		end

		def add_user(user_object, tag_name, tag_value, users)
			user = {}
			user[:user_name] = user_object.user_name
			user[:full_name] = user_object.full_name
			user[:shell] = user_object.shell
			user[:public_key] = user_object.public_key
			user[:public_key_expire] = user_object.public_key_expire
			user[:user_id] = user_object.user_id.to_i
			user[:identity] = user_object.identity.to_i
			user[:sudo] = user_object.access_tags[tag_name][tag_value]['sudo']
			user[:files] = user_object.files
			users[:local_users][user_object.user_name] = user
		end

		def load_instance_tags()
			instance_id = @instance_data['instance-id']
			ec2 = AWS::EC2.new()
			intsance_tags = ec2.instances[instance_id].tags.to_h
			tag_names = intsance_tags.keys & @server_users.tags.to_a
			tag_names.each do |tag|
				@tags[tag] = intsance_tags[tag]
			end
		end

		def update_required?(local_users)
		end

	end
end
