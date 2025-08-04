class BlueskyPostFetcher
  def initialize(user)
    @user = user
  end

  def fetch_latest_posts(limit: 10)
    return [] unless @user.has_valid_bluesky_token?
    
    begin
      pds_endpoint = @user.pds_endpoint
      return [] unless pds_endpoint
      
      # Use public API for public posts, authenticated API for user's own posts
      response = fetch_from_pds(pds_endpoint, limit)
      
      if response.success?
        parse_blog_posts(response)
      else
        Rails.logger.warn "Failed to fetch Bluesky posts for #{@user.handle}: #{response.status} - #{response.body}"
        []
      end
    rescue => e
      Rails.logger.error "Error fetching Bluesky posts for #{@user.handle}: #{e.message}"
      []
    end
  end

  def fetch_post_by_uri(at_uri)
    puts "=== fetch_post_by_uri called with: #{at_uri} ==="
    return nil unless @user.has_valid_bluesky_token?
    return nil unless at_uri.start_with?('at://')
    
    begin
      pds_endpoint = @user.pds_endpoint
      puts "PDS endpoint: #{pds_endpoint}"
      return nil unless pds_endpoint
      
      # Parse the AT URI to get the repo and rkey
      uri_parts = at_uri.match(%r{^at://([^/]+)/([^/]+)/([^/]+)$})
      puts "URI parts: #{uri_parts&.to_a}"
      return nil unless uri_parts
      
      repo = uri_parts[1]
      collection = uri_parts[2]
      rkey = uri_parts[3]
      
      response = Faraday.get("#{pds_endpoint}/xrpc/com.atproto.repo.getRecord") do |req|
        req.params['repo'] = repo
        req.params['collection'] = collection
        req.params['rkey'] = rkey
        req.headers['Authorization'] = "Bearer #{@user.access_token}"
        puts "=== fetch_post_by_uri Debug ==="
        puts "URL: #{pds_endpoint}/xrpc/com.atproto.repo.getRecord"
        puts "Params: repo=#{repo}, collection=#{collection}, rkey=#{rkey}"
      end
      
      puts "Response status: #{response.status}"
      puts "Response body: #{response.body[0..100]}"
      
      if response.success?
        data = JSON.parse(response.body)
        parse_single_post(data, at_uri)
      else
        Rails.logger.warn "Failed to fetch Bluesky post #{at_uri}: #{response.status}"
        nil
      end
    rescue => e
      puts "Exception in fetch_post_by_uri: #{e.class} - #{e.message}"
      Rails.logger.error "Error fetching Bluesky post #{at_uri}: #{e.message}"
      nil
    end
  end

  private

  def fetch_from_pds(pds_endpoint, limit)
    url = "#{pds_endpoint}/xrpc/com.atproto.repo.listRecords"
    Rails.logger.debug "Fetching from URL: #{url}"
    puts "=== fetch_from_pds Debug ==="
    puts "URL: #{url}"
    
    begin
      response = Faraday.get(url) do |req|
        req.params['repo'] = @user.uid # User's DID
        req.params['collection'] = 'com.whtwnd.blog.entry'
        req.params['limit'] = limit
        req.params['reverse'] = true # Most recent first
        
        Rails.logger.debug "Request params: #{req.params}"
        puts "Request params: #{req.params}"
        
        # Use authentication if available for better access
        if @user.access_token.present?
          req.headers['Authorization'] = "Bearer #{@user.access_token}"
          puts "Added Authorization header"
        end
      end
      
      puts "Response received successfully!"
      puts "Response status: #{response.status}"
      puts "Response body (first 200 chars): #{response.body[0..200]}"
      response
    rescue => e
      puts "Exception in fetch_from_pds: #{e.class} - #{e.message}"
      puts "Backtrace: #{e.backtrace.first(3)}"
      raise e
    end
  end

  def parse_blog_posts(response)
    data = JSON.parse(response.body)
    records = data['records'] || []
    
    records.map do |record|
      parse_record(record)
    end.compact.select { |post| post[:visibility] == 'public' }
  end

  def parse_record(record)
    value = record['value'] || {}
    
    {
      uri: record['uri'],
      cid: record['cid'],
      title: value['title'],
      content: value['content'],
      created_at: value['createdAt'],
      visibility: value['visibility'] || 'public',
      word_count: estimate_word_count(value['content']),
      preview: generate_preview(value['content'])
    }
  end

  def parse_single_post(data, uri)
    value = data['value'] || {}
    
    {
      uri: uri,
      cid: data['cid'],
      title: value['title'],
      content: value['content'],
      created_at: value['createdAt'],
      visibility: value['visibility'] || 'public',
      word_count: estimate_word_count(value['content']),
      preview: generate_preview(value['content'])
    }
  end

  def estimate_word_count(content)
    return 0 unless content.present?
    
    # Simple word count - split by whitespace and count
    content.to_s.split(/\s+/).length
  end

  def generate_preview(content, max_length: 300)
    return '' unless content.present?
    
    # Strip markdown/HTML and create a preview
    text = content.to_s.gsub(/[#*_`\[\]()>-]/, '').strip
    
    if text.length > max_length
      text.first(max_length).split(' ')[0..-2].join(' ') + '...'
    else
      text
    end
  end
end
