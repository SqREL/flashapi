# frozen_string_literal: true

module FlashAPI
  # Adapters module provides server adapter management and registration
  module Adapters
    class << self
      def register(name, adapter_class)
        adapters[name.to_sym] = adapter_class
      end

      def get(name)
        adapters.fetch(name.to_sym) do
          raise AdapterNotFound, "Adapter '#{name}' not found. Available adapters: #{available_adapters.join(', ')}"
        end
      end

      def available_adapters = adapters.keys

      private

      def adapters
        @adapters ||= {}
      end
    end

    # Base adapter class that all adapters should inherit from
    class Base
      attr_reader :app, :options

      def initialize(app, **options)
        @app = app
        @options = options
      end

      # Start the server - must be implemented by subclasses
      def start
        raise NotImplementedError, "#{self.class} must implement #start method"
      end

      # Stop the server - must be implemented by subclasses  
      def stop
        raise NotImplementedError, "#{self.class} must implement #stop method"
      end

      private

      # Handle incoming request and return response
      def handle_request(request)
        responder_class = Application.run(request, app)
        responder = responder_class.new(request)
        
        # Call the responder if it implements call method
        responder.call if responder.respond_to?(:call)

        {
          status: responder.status_code,
          headers: responder.headers,
          body: responder.body
        }
      rescue NoRouteMatch => e
        error_response(404, e.message)
      rescue StandardError => e
        error_response(500, "Internal Server Error: #{e.message}")
      end

      def error_response(status, message)
        body = Oj.dump({ status_code: status, success: false, error: message }, mode: :compat)
        
        {
          status:,
          headers: { 'Content-Type' => 'application/json' },
          body:
        }
      end
    end
  end
end