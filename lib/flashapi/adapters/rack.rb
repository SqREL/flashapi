# frozen_string_literal: true

require 'rack'
require_relative '../object_pool'

module FlashAPI
  module Adapters
    # Rack adapter for FlashAPI framework with object pooling optimizations
    class Rack < Base
      # Class-level pools shared across all instances
      RACK_REQUEST_POOL = RackRequestPool.new(size: 100)
      BASE_REQUEST_POOL = BaseRequestPool.new(size: 100)
      def self.build_app(app, **options)
        new(app, **options)
      end

      def call(env)
        request = build_request(env)
        response = handle_request(request)
        
        body = response[:body]
        
        # Check if body is streamable (responds to each)
        if body.respond_to?(:each) && !body.is_a?(String)
          [response[:status], response[:headers], body]
        else
          [response[:status], response[:headers], [body]]
        end
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
        if use_pooling?
          build_pooled_request(env)
        else
          build_standard_request(env)
        end
      end

      private

      def use_pooling?
        options.fetch(:use_pooling, true)
      end

      def build_pooled_request(env)
        RACK_REQUEST_POOL.with_request(env) do |rack_request|
          BASE_REQUEST_POOL.build_request do |builder|
            builder
              .set(:protocol, rack_request.scheme)
              .set(:request_method, rack_request.request_method)
              .set(:cookie, rack_request.cookies)
              .set(:content_type, rack_request.content_type)
              .set(:path_info, rack_request.path_info)
              .set(:uri, rack_request.path_info)
              .set(:query_string, rack_request.query_string)
              .set(:post_content, read_body(rack_request))
              .set(:headers, extract_headers(env))
          end
        end
      end

      def build_standard_request(env)
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

      # Frozen string constants for header optimization
      HTTP_PREFIX = 'HTTP_'
      UNDERSCORE = '_'
      DASH = '-'
      CONTENT_HEADERS = %w[CONTENT_TYPE CONTENT_LENGTH].freeze

      def extract_headers(env)
        headers = {}
        
        env.each do |key, value|
          if key.start_with?(HTTP_PREFIX)
            # Use frozen strings and avoid intermediate arrays
            header_name = key[5..].tr(UNDERSCORE, DASH).split(DASH).map(&:capitalize).join(DASH)
            headers[header_name] = value
          elsif CONTENT_HEADERS.include?(key)
            headers[key.tr(UNDERSCORE, DASH).split(DASH).map(&:capitalize).join(DASH)] = value
          end
        end
        
        headers
      end
    end

    # Register the Rack adapter
    register(:rack, Rack)
  end
end