module AsCombinedMetrics::Cli::CloudFormation
  def describe_stack(logical_resource_id)
    logger.progname = "#{Module.nesting.first.to_s} #{__method__}"

    logger.info { set_color  "Getting the full name for the resource => #{logical_resource_id}", :white }
    counter = 1
    @autoscale_group_name = nil
    @print_log = true
    physical_resource_id = nil

    until physical_resource_id
      begin
        stack_info = @cfm.describe_stack_resource({
          :stack_name => @stack_name,
          :logical_resource_id => logical_resource_id
        })

        if !stack_info.nil?
          physical_resource_id = stack_info.stack_resource_detail.physical_resource_id
          record_resource(stack_info.stack_resource_detail.resource_type, physical_resource_id)
          File.open(options[:config_file], "w") { |f| f.write(@config.to_yaml) }
        end
      rescue Exception => e
        if e.to_s.match (/Stack with name\s\S+\sdoes not exist/)
          logger.fatal { set_color "Stack name was not found", :red }
          exit 1
        end

        # A spot fleet deployed one-per-subnet is not in the stack under its own name: the deploy
        # replaces it with one fleet per subnet named <logical id><subnet suffix> (for example
        # BackEndSpotFleet376b1e6a). Take every spot fleet whose logical id starts with the one we
        # were given.
        fleets = spot_fleets_with_prefix(logical_resource_id)
        if !fleets.empty?
          fleets.each { |fleet| record_resource("AWS::EC2::SpotFleet", fleet.physical_resource_id, fleet.logical_resource_id) }
          File.open(options[:config_file], "w") { |f| f.write(@config.to_yaml) }
          physical_resource_id = fleets.first.physical_resource_id
          next
        end

        if @print_log
          logger.error { set_color  "Unable to find the resource - #{e}, maybe wrong region or wrong AWS account?", :yellow }
          logger.info { "Will retry every 5 seconds up to maximum of #{options[:timeout]} seconds" }
        end

        interval = 5
        if counter < options[:timeout].to_i
          counter += interval
          @print_log = false
          sleep interval
        else
          logger.fatal { set_color  "Timeout Error  - Unable to get the full AutoScale group name for the stack #{@stack_name} for #{options[:timeout]} seconds", :red }
          exit 1
        end
      end
    end
  end

  # Every AWS::EC2::SpotFleet of the stack whose logical id starts with prefix, across all
  # pages of list_stack_resources. An error (throttling, access) is logged and gives an empty
  # list, so the caller's retry loop keeps going.
  def spot_fleets_with_prefix(prefix)
    fleets = []
    next_token = nil
    loop do
      page = @cfm.list_stack_resources({ :stack_name => @stack_name, :next_token => next_token }.compact)
      fleets += page.stack_resource_summaries.select { |r|
        r.resource_type == "AWS::EC2::SpotFleet" && r.logical_resource_id.start_with?(prefix)
      }
      next_token = page.next_token
      break if next_token.nil?
    end
    fleets
  rescue Exception => e
    logger.warn { set_color "Unable to list the stack resources - #{e}", :yellow }
    []
  end

  def record_resource(resource_type, physical_resource_id, logical_resource_id = nil)
    return if physical_resource_id.nil? || physical_resource_id.empty?
    if resource_type == "AWS::EC2::SpotFleet"
      @config[:spot_fleet_id] ||= []
      @config[:spot_fleet_id] << physical_resource_id unless @config[:spot_fleet_id].include?(physical_resource_id)
      logger.info { set_color  "Spot Fleet ID: #{physical_resource_id}#{logical_resource_id ? " (#{logical_resource_id})" : ''}", :cyan }
    else # default is good old auto scale group
      @autoscale_group_name = physical_resource_id
      @config[:autoscale_group_name] ||= []
      @config[:autoscale_group_name] << physical_resource_id unless @config[:autoscale_group_name].include?(physical_resource_id)
      logger.info { set_color  "AutoScale Group Name: #{physical_resource_id}", :cyan }
    end
  end
end
