# frozen_string_literal: true

module FlashAPI
  # BaseRequest using Ruby 3.2+ Data class for immutable request representation
  BaseRequest = Data.define(
    :protocol,
    :request_method,
    :cookie,
    :content_type,
    :path_info,
    :uri,
    :query_string,
    :post_content,
    :headers
  ) do
    # Initialize with default values for optional fields
    def initialize(protocol: nil, request_method: nil, cookie: nil,
                   content_type: nil, path_info: nil, uri: nil,
                   query_string: nil, post_content: nil, headers: {})
      super
    end

    # Helper methods for common checks
    def get? = request_method&.downcase == 'get'
    def post? = request_method&.downcase == 'post'
    def put? = request_method&.downcase == 'put'
    def delete? = request_method&.downcase == 'delete'
    def patch? = request_method&.downcase == 'patch'

    # Check if request has JSON content type
    def json?
      return false if content_type.nil? || content_type.empty?
      
      content_type.downcase.include?('application/json')
    end

    # Get a specific header value (case-insensitive)
    def header(name)
      return nil unless headers.is_a?(Hash)
      
      headers.find { |k, _| k.to_s.downcase == name.to_s.downcase }&.last
    end

    # Parse query string into hash
    def query_params
      return {} if query_string.nil? || query_string.empty?
      
      # Handle both URI and Rack-style query strings
      require 'cgi'
      CGI.parse(query_string).transform_values(&:first)
    rescue StandardError
      {}
    end

    # Parse POST content as JSON if applicable
    def json_body
      return {} unless json?
      return {} if post_content.nil? || post_content.empty?
      
      Oj.load(post_content, symbol_keys: true)
    rescue StandardError
      {}
    end
  end
end