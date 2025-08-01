require 'openssl'
require 'json'
require 'base64'
require 'securerandom'

module OmniAuth
  module Atproto
    class KeyManager
      PRIVATE_KEY_PATH = Rails.root.join('config', 'atproto_private_key.pem')
      JWK_PATH = Rails.root.join('config', 'atproto_jwk.json')

      class << self
        def current_private_key
          return @private_key if @private_key && File.exist?(PRIVATE_KEY_PATH)
          
          generate_keys unless File.exist?(PRIVATE_KEY_PATH)
          @private_key = OpenSSL::PKey::EC.new(File.read(PRIVATE_KEY_PATH))
        end

        def current_jwk
          return @jwk if @jwk && File.exist?(JWK_PATH)
          
          generate_keys unless File.exist?(JWK_PATH)
          @jwk = JSON.parse(File.read(JWK_PATH))
        end

        def generate_keys
          Rails.logger.info "Generating new AT Protocol EC key pair..."
          
          # Generate EC P-256 key pair for ES256 (as required by AT Protocol)
          key = OpenSSL::PKey::EC.generate('prime256v1')
          
          # Save private key
          File.write(PRIVATE_KEY_PATH, key.to_pem)
          File.chmod(0600, PRIVATE_KEY_PATH) # Secure permissions
          
          # Generate JWK for EC key
          public_key_point = key.public_key
          x = public_key_point.to_bn(:uncompressed).to_s(2)[1..32]
          y = public_key_point.to_bn(:uncompressed).to_s(2)[33..64]
          
          jwk = {
            kty: 'EC',
            crv: 'P-256',
            x: Base64.urlsafe_encode64(x, padding: false),
            y: Base64.urlsafe_encode64(y, padding: false),
            use: 'sig',
            alg: 'ES256',
            kid: SecureRandom.uuid
          }
          
          File.write(JWK_PATH, JSON.pretty_generate(jwk))
          File.chmod(0600, JWK_PATH) # Secure permissions
          
          Rails.logger.info "AT Protocol keys generated successfully"
          Rails.logger.info "Private key: #{PRIVATE_KEY_PATH}"
          Rails.logger.info "JWK: #{JWK_PATH}"
          
          # Clear cached keys
          @private_key = nil
          @jwk = nil
          
          { private_key: key, jwk: jwk }
        end

        def rotate_keys
          # Backup existing keys if they exist
          if File.exist?(PRIVATE_KEY_PATH)
            backup_timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
            FileUtils.cp(PRIVATE_KEY_PATH, "#{PRIVATE_KEY_PATH}.backup_#{backup_timestamp}")
            Rails.logger.info "Backed up private key to #{PRIVATE_KEY_PATH}.backup_#{backup_timestamp}"
          end
          
          if File.exist?(JWK_PATH)
            backup_timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
            FileUtils.cp(JWK_PATH, "#{JWK_PATH}.backup_#{backup_timestamp}")
            Rails.logger.info "Backed up JWK to #{JWK_PATH}.backup_#{backup_timestamp}"
          end
          
          generate_keys
        end

        def keys_exist?
          File.exist?(PRIVATE_KEY_PATH) && File.exist?(JWK_PATH)
        end
      end
    end
  end
end
