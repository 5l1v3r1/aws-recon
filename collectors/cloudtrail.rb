class CloudTrail < Mapper
  #
  # Returns an array of resources.
  #
  def collect
    resources = []
    #
    # describe_trails
    #
    @client.describe_trails.each_with_index do |response, page|
      log(response.context.operation_name, page)

      response.trail_list.each do |trail|
        # list_tags needs to call into home_region
        client = if @region != trail.home_region
                   Aws::CloudTrail::Client.new({ region: trail.home_region })
                 else
                   @client
                 end

        struct = OpenStruct.new(trail.to_h)
        struct.tags = client.list_tags({ resource_id_list: [trail.trail_arn] }).resource_tag_list.first.tags_list
        struct.type = 'cloud_trail'
        struct.status = client.get_trail_status({ name: trail.name }).to_h
        struct.arn = trail.trail_arn

      rescue Aws::CloudTrail::Errors::ServiceError => e
        log_error(e.code)
        raise e unless suppressed_errors.include?(e.code)
      ensure
        resources.push(struct.to_h)
      end
    end

    resources
  end

  private

  # not an error
  def suppressed_errors
    %w[
      CloudTrailARNInvalidException
    ]
  end
end
