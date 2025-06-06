# frozen_string_literal: true

module FlashAPI
  # Responder module provides JSON response handling with modern Ruby syntax
  module Responder
    # Default response values
    DEFAULT_STATUS_CODE = 200
    DEFAULT_HEADERS = { 'Content-Type' => 'application/json' }.freeze

    def status_code = render[:status_code] || default_status_code

    def headers = render[:headers] || default_headers

    def body
      Oj.dump(build_response_body, mode: :compat)
    end

    # Render method to be implemented by including class
    def render
      raise NotImplementedError, "#{self.class} must implement #render method returning a hash"
    end

    private

    def default_status_code = DEFAULT_STATUS_CODE

    def default_headers = DEFAULT_HEADERS.dup

    def build_response_body
      {
        status_code:,
        success: success?
      }.merge(render[:body] || {})
    end

    def success? = status_code.between?(200, 299)
  end

  # Base responder class that can be inherited for concrete responders
  class BaseResponder
    include Responder

    attr_reader :request, :params

    def initialize(request)
      @request = request
      @params = extract_params
    end

    # Call method to handle the request - override in subclasses
    def call
      raise NotImplementedError, "#{self.class} must implement #call method"
    end

    # Default render method for BaseResponder
    def render
      @render_result || ok
    end

    private

    def extract_params
      if request.post? || request.put? || request.patch?
        request.query_params.merge(request.json_body)
      else
        request.query_params
      end
    end

    # Helper methods for common responses
    def ok(body = {})
      { status_code: 200, body: }
    end

    def created(body = {})
      { status_code: 201, body: }
    end

    def no_content
      { status_code: 204, body: {} }
    end

    def bad_request(message = 'Bad Request')
      { status_code: 400, body: { error: message } }
    end

    def unauthorized(message = 'Unauthorized')
      { status_code: 401, body: { error: message } }
    end

    def forbidden(message = 'Forbidden')
      { status_code: 403, body: { error: message } }
    end

    def not_found(message = 'Not Found')
      { status_code: 404, body: { error: message } }
    end

    def unprocessable_entity(errors = {})
      { status_code: 422, body: { errors: } }
    end

    def internal_server_error(message = 'Internal Server Error')
      { status_code: 500, body: { error: message } }
    end
  end
end