namespace :atproto do
  desc "Generate new AT Protocol key pair"
  task generate_keys: :environment do
    OmniAuth::Atproto::KeyManager.generate_keys
    puts "✅ New AT Protocol keys generated successfully"
    puts "   Private key: config/atproto_private_key.pem"
    puts "   JWK: config/atproto_jwk.json"
  end

  desc "Generate new AtProto key pair and rotate keys"
  task rotate_keys: :environment do
    OmniAuth::Atproto::KeyManager.rotate_keys
    puts "✅ Keys rotated successfully. Old keys backed up."
    puts "   Private key: config/atproto_private_key.pem"
    puts "   JWK: config/atproto_jwk.json"
  end

  desc "Generate client metadata JSON file"
  task generate_metadata: :environment do
    metadata = {
      client_id: "#{Rails.application.config.app_url}/oauth/client-metadata.json",
      application_type: "web",
      client_name: Rails.application.class.module_parent_name,
      client_uri: Rails.application.config.app_url,
      dpop_bound_access_tokens: true,
      grant_types: %w[authorization_code refresh_token],
      redirect_uris: [ "#{Rails.application.config.app_url}/auth/atproto/callback" ],
      response_types: [ "code" ],
      scope: "atproto transition:generic",
      token_endpoint_auth_method: "private_key_jwt",
      token_endpoint_auth_signing_alg: "ES256",
      jwks: {
        keys: [ OmniAuth::Atproto::KeyManager.current_jwk ]
      }
    }

    oauth_dir = Rails.root.join("public", "oauth")
    FileUtils.mkdir_p(oauth_dir) unless Dir.exist?(oauth_dir)
    metadata_path = oauth_dir.join("client-metadata.json")
    File.write(metadata_path, JSON.pretty_generate(metadata))
    puts "Generated metadata file at #{metadata_path}"
  end
end
