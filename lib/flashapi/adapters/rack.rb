# frozen_string_literal: true

require 'rack'

module FlashAPI
  module Adapters
    # Rack adapter for FlashAPI framework
    class Rack < Base
      def self.build_app(app, **options)
        new(app, **options)
      end

      def call(env)
        request = build_request(env)
        response = handle_request(request)
        
        [response[:status], response[:headers], [response[:body]]]
      end

      def start
        server.start
      end

      def stop
        server.shutdown if server.respond_to?(:shutdown)
      end

      private

      def server
        @server ||= ::Rack::Server.new(
          app: self,
          Port: options[:port] || 3000,
          Host: options[:host] || '0.0.0.0',
          server: options[:server] || 'webrick',
          **server_options
        )
      end

      def server_options
        options.slice(:AccessLog, :Logger, :environment, :pid, :config)
      end

      def build_request(env)
        rack_request = ::Rack::Request.new(env)
        
        BaseRequest.new(
          protocol: rack_request.scheme,
          request_method: rack_request.request_method,
          cookie: rack_request.cookies,
          content_type: rack_request.content_type,
          path_info: rack_request.path_info,
          uri: rack_request.path_info,
          query_string: rack_request.query_string,
          post_content: read_body(rack_request),
          headers: extract_headers(env)
        )
      end

      def read_body(rack_request)
        return nil unless rack_request.post? || rack_request.put? || rack_request.patch?
        
        body = rack_request.body.read
        rack_request.body.rewind
        body
      end

      def extract_headers(env)
        env.each_with_object({}) do |(key, value), headers|
          if key.start_with?('HTTP_')
            header_name = key[5..].split('_').map(&:capitalize).join('-')
            headers[header_name] = value
          elsif %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)
            headers[key.split('_').map(&:capitalize).join('-')] = value
          end
        end
      end
    end

    # Register the Rack adapter
    register(:rack, Rack)
  end
end