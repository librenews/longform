require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :faraday
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  
  # Filter sensitive data
  config.filter_sensitive_data('<BLUESKY_ACCESS_TOKEN>') { ENV['BLUESKY_ACCESS_TOKEN'] }
  config.filter_sensitive_data('<BLUESKY_CLIENT_ID>') { ENV['BLUESKY_CLIENT_ID'] }
  config.filter_sensitive_data('<BLUESKY_CLIENT_SECRET>') { ENV['BLUESKY_CLIENT_SECRET'] }
  
  # Allow localhost connections for test server
  config.ignore_localhost = true
  
  # Ignore test domains used in WebMock
  config.ignore_request do |request|
    URI(request.uri).host.in?(['test.pds.host', 'plc.directory', 'bsky.social'])
  end
  
  # Default cassette options
  config.default_cassette_options = {
    record: :once,
    re_record_interval: 7.days
  }
end

# RSpec integration
RSpec.configure do |config|
  # Use VCR for any test tagged with :vcr
  config.before(:each, :vcr) do |example|
    name = example.metadata[:description_args].first
    options = example.metadata.slice(:record, :match_requests_on).compact
    VCR.use_cassette(name, options) do
      example.run
    end
  end
end
