namespace :bluesky do
  desc "Test Bluesky API connection"
  task test_connection: :environment do
    result = BlueskySessionManager.test_connection
    if result[:success]
      puts "✅ Successfully connected to Bluesky AT Protocol API"
      puts "Server info: #{result[:server_info]}"
    else
      puts "❌ Failed to connect: #{result[:error]}"
    end
  end
  
  desc "Test Bluesky session creation with app password"
  task :test_session, [:identifier, :password] => :environment do |task, args|
    if args[:identifier].blank? || args[:password].blank?
      puts "Usage: rails bluesky:test_session[handle.bsky.social,app-password]"
      puts "Get app password from: https://bsky.app/settings/app-passwords"
      exit 1
    end
    
    manager = BlueskySessionManager.new(args[:identifier], args[:password])
    result = manager.create_session
    
    if result[:success]
      puts "✅ Successfully created Bluesky session"
      puts "DID: #{result[:did]}"
      puts "Handle: #{result[:handle]}"
      puts "Access token present: #{result[:access_jwt].present?}"
    else
      puts "❌ Failed to create session: #{result[:error]}"
    end
  end
  
  desc "Test publishing a post to Bluesky"
  task :test_publish, [:post_id, :identifier, :password] => :environment do |task, args|
    if args[:post_id].blank? || args[:identifier].blank? || args[:password].blank?
      puts "Usage: rails bluesky:test_publish[post_id,handle.bsky.social,app-password]"
      exit 1
    end
    
    post = Post.find(args[:post_id])
    credentials = {
      identifier: args[:identifier],
      password: args[:password]
    }
    
    publisher = BlueskyPublisher.new(post, credentials)
    result = publisher.publish
    
    if result[:success]
      puts "✅ Successfully published to Bluesky!"
      puts "URI: #{result[:uri]}"
      puts "CID: #{result[:cid]}"
      
      # Update the post with Bluesky info
      post.update!(
        bluesky_uri: result[:uri],
        bluesky_cid: result[:cid],
        bluesky_metadata: result[:metadata]
      )
      puts "Post updated with Bluesky metadata"
    else
      puts "❌ Failed to publish: #{result[:error]}"
      puts "Details: #{result[:details]}" if result[:details]
    end
  end
end
