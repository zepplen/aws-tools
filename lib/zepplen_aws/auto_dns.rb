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

	# Utalized by the zepplen_dns script to update Route53 zones with dns entries based on
	# the infrastructure.
	#
	# This class makes heavy use of the Env options to retrieve it's parameters.
	class AutoDNS
		require 'colorize'

		def initialize()
			@dns_precidence = 0
			@dns_pool = []
			@new_dns_pools = nil
			@live_dns_pools = nil
			@dns_entries = {}
			@dns_entries[:public] = {}
			@dns_entries[:private] = {}
			@zones = {}
			@zones[:public] = {}
			@zones[:private] = {}
			@options = Env::options
			@ec2 = AWS::EC2.new()
			@elb = AWS::ELB.new()
			@route53 = AWS::Route53.new()
			populate_zones()
		end

		# Process the existing infrusturecte as defined in the Env Options, and update
		# Route 53 with the deltas.
		def run!()
			if(@options[:elb])
				process_elbs()
			end
			next_precience()
			if(@options[:ec2_tags])
				@options[:ec2_tags].each do |tag_name|
					process_ec2_tag_name(tag_name)
					next_precience()
				end
			end
			reduce_dns_pool()
			process_zone_updates()
		end

		private

		def populate_zones()
			if(@options[:public_zones])
				zone_id_search(@options[:public_zones], @zones[:public])
			end
			if(@options[:private_zones])
				zone_id_search(@options[:private_zones], @zones[:private])
			end
			if(@options[:private_zone_names])
				zone_name_search(@options[:private_zone_names], @zones[:private])
			end
		end

		def zone_id_search(zone_ids, zone_pool)
			zone_ids.each do |zone_id|
				zone_pool[zone_id] = @route53.hosted_zones[zone_id]
			end
		end

		def zone_name_search(zone_names, zone_pool)
			@route53.hosted_zones.each do |hosted_zone|
				zone_names.each do |zone_name|
					if(hosted_zone.name == zone_name)
						zone_pool[hosted_zone.id] = hosted_zone
					end
				end
			end
		end

		def process_zone_updates()
			@zones.each_pair do |pool_type, zones|
				zones.each_pair do |zone_id, zone|
					process_updates(pool_type, zone)
				end
			end
		end

		def process_updates(pool_type, zone)
			if(@new_dns_pools.has_key?(pool_type))
				live_zone_pool = {}
				zone.resource_record_sets.each do |record|
					if(record.type == 'CNAME' || record.type == 'A')
						name = record.name.gsub(/^\\052/, '*')
						live_zone_pool[name] = {:name => name, :type => record.type, :ttl => record.ttl , :value => record.resource_records}
					end
				end
				to_add, to_delete = diff_zones(live_zone_pool, @new_dns_pools[pool_type], zone)
				log_actions_to_take(to_add, to_delete, zone, pool_type)
				if(@options[:commit])
					change_batch = ::AWS::Route53::ChangeBatch.new(zone.id)
					to_delete.each_pair do |key, dns_data|
						change_batch << ::AWS::Route53::DeleteRequest.new(dns_data[:name], dns_data[:type], :ttl => dns_data[:ttl], :resource_records => dns_data[:value])
					end
					to_add.each_pair do |key, dns_data|
						change_batch << ::AWS::Route53::CreateRequest.new("#{dns_data[:name]}.#{zone.name}", dns_data[:type], :ttl => dns_data[:ttl], :resource_records => dns_data[:value])
					end
					if(change_batch.length > 0)
						change_batch.call
					end
				else
					puts "Not in --commit mode".red
				end
			end
		end

		def log_actions_to_take(to_add, to_delete, zone, pool_type)
			puts "Updating #{pool_type.to_s} #{zone.name}:#{zone.id}".green
			if(to_delete.length > 0)
				puts "Deleting:".yellow
				to_delete.each_pair do |key, dns_data|
					puts "\t#{dns_data[:name]}:".yellow
					puts "\t\tType: #{dns_data[:type]}".yellow
					puts "\t\tTTL: #{dns_data[:ttl]}".yellow
					puts "\t\tValue: #{dns_data[:value]}".yellow
				end
			else
				puts "Nothing To Delete".yellow
			end
			if(to_add.length > 0)
				puts "Adding:".light_blue
				to_add.each_pair do |key, dns_data|
					puts "\t#{dns_data[:name]}.#{zone.name}:".light_blue
					puts "\t\tType: #{dns_data[:type]}".light_blue
					puts "\t\tTTL: #{dns_data[:ttl]}".light_blue
					puts "\t\tValue: #{dns_data[:value]}".light_blue
				end
			else
				puts "Nothing To Add".light_blue
			end
		end

		def diff_zones(live_zone, new_zone, zone)
			live_zone_agg = generate_zone_aggrigate(live_zone, '')
			new_zone_agg = generate_zone_aggrigate(new_zone, ".#{zone.name}")
			to_add_keys = new_zone_agg.keys - live_zone_agg.keys
			to_del_keys = live_zone_agg.keys - new_zone_agg.keys
			to_add = new_zone_agg.select{|k,v| to_add_keys.include?(k)}
			to_del = live_zone_agg.select{|k,v| to_del_keys.include?(k)}
			return [to_add, to_del]
		end

		def generate_zone_aggrigate(zone, domain)
			zone_agg = {}
			zone.each_pair do |name, zone_data|
				key = "#{name}#{domain}|#{zone_data[:type]}|#{zone_data[:ttl]}|#{zone_data[:value].join(',')}"
				zone_agg[key] = zone_data
			end
			return zone_agg
		end

		def reduce_dns_pool()
			@new_dns_pools = {}
			@dns_pool.each do |dns_set|
				dns_set.each_pair do |key, dns_entries|
					if(!@new_dns_pools.has_key?(key))
						@new_dns_pools[key] = {}
					end
					dns_entries.each_pair do |name, dns_data|
						if(!@new_dns_pools[key].has_key?(name))
								@new_dns_pools[key][name] = dns_data
						end
					end
				end
			end
		end

		def next_precience()
			@dns_precidence += 1
			@dns_pool << @dns_entries
			@dns_entries = {}
			@dns_entries[:public] = {}
			@dns_entries[:private] = {}
		end

		def process_ec2_tag_name(tag_name)
			@ec2.instances.filter('instance-state-name', 'running').each do |instance|
				if(instance.tags.has_key?(tag_name))
					instance.tags[tag_name].split(',').each do |tag_value|
						if(@options[:dns_type] == :CNAME)
							add_dns_entry(tag_value, @options[:dns_type], @options[:ttl], instance.dns_name, instance.private_dns_name, @options[:wildcards])
						else
							add_dns_entry(tag_value, @options[:dns_type], @options[:ttl], instance.ip_address, instance.private_ip_address, @options[:wildcards])
						end
					end
				end
			end
		end

		def process_elbs()
			@elb.load_balancers.each do |load_balancer|
				add_dns_entry(load_balancer.name, :CNAME, @options[:ttl], load_balancer.dns_name, load_balancer.dns_name, @options[:wildcards])
			end
		end

		def add_dns_entry(name, type, ttl, public_value, private_value, wildcards)
			name = sanatize_name(name)
			if(@dns_entries[:public].has_key?(name))
				puts "Duplicate name found at same precidence level: #{name}"
			else
				@dns_entries[:public][name] = {:name => name, :type => type.to_s.upcase, :ttl => ttl , :value => [{:value => public_value}]}
				@dns_entries[:private][name] = {:name => name, :type => type.to_s.upcase, :ttl => ttl , :value => [{:value => private_value}]}
				if(wildcards)
					name = "*.#{name}"
					@dns_entries[:public][name] = {:name => name, :type => type.to_s.upcase, :ttl => ttl , :value => [{:value => public_value}]}
					@dns_entries[:private][name] = {:name => name, :type => type.to_s.upcase, :ttl => ttl , :value => [{:value => private_value}]}
				end
			end
		end

		def sanatize_name(name)
			name = name.gsub(/[^a-zA-Z0-9]+/, '-')
			name = name.gsub(/^-*|-*$/, '')
			return name.downcase
		end
		
	end
end
