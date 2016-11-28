require 'sinatra'
require 'sinatra/json'
require 'sinatra/param'

require 'ledenet_api'
require 'bravtroller'
require 'easy_upnp'
require 'color'
require 'openssl'
require 'net/ping'

require 'open-uri'

require_relative 'helpers/config_provider'

module HaGateway
  class App < Sinatra::Application
    before do
      logger.info "Params: #{params.inspect}"
    end
    
    before do
      if security_enabled?
        timestamp = request.env['HTTP_X_SIGNATURE_TIMESTAMP']
        signature = request.env['HTTP_X_SIGNATURE']
        signed_params = (request.put? || request.post?) ? request.POST : {}
        payload = request.path_info + signed_params.sort.join + timestamp

        if [payload, timestamp, signature].any?(&:nil?)
          logger.info "Access denied: incomplete signature params."
          logger.info "timestamp = #{timestamp}, payload = #{payload}, signature = #{signature}"
          halt 403
        end

        digest = OpenSSL::Digest.new('sha1')
        hmac = OpenSSL::HMAC.hexdigest(digest, config_value(:hmac_secret), payload)

        if hmac != signature
          logger.info "Access denied: incorrect signature. Computed = '#{hmac}', provided = '#{signature}'"
          halt 403
        end

        if ((Time.now.to_i - 20) > timestamp.to_i)
          logger.info "Invalid parameter. Timestamp expired: #{timestamp}"
          halt 412
        end
      end
    end
  end
end

require_relative 'helpers/init'
require_relative 'routes/init'
