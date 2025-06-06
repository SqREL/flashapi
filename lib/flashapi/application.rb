# frozen_string_literal: true

module FlashAPI
  # Application router with modern Ruby pattern matching and proper error handling
  class Application
    class << self
      def run(request, scope)
        validate_scope!(scope)
        
        route = find_route(request, scope)
        instantiate_responder(route[:responder], scope)
      end

      private

      def validate_scope!(scope)
        return if scope.const_defined?(:Routes) && scope::Routes.respond_to?(:paths)
        
        raise ArgumentError, "Invalid scope: #{scope} must define Routes.paths"
      end

      def find_route(request, scope)
        routes = scope::Routes.paths
        
        # Handle nil request method or URI
        if request.request_method.nil? || request.uri.nil?
          raise NoRouteMatch, "Invalid request: method and URI cannot be nil"
        end
        
        route_key = "#{request.request_method.upcase} #{request.uri}"
        
        case routes[route_key]
        in { method:, responder:, path: }
          { responder: }
        in nil
          # Check if path exists with different method
          path_routes = routes.select { |key, _| key.end_with?(" #{request.uri}") }
          if path_routes.any?
            available_methods = path_routes.keys.map { |key| key.split(' ', 2).first }.join(', ')
            raise NoRouteMatch, "Method not allowed: #{request.request_method} for #{request.uri}. Available methods: #{available_methods}"
          else
            raise NoRouteMatch, "No route found for: #{request.uri}"
          end
        end
      end


      def instantiate_responder(responder_name, scope)
        begin
          scope.const_get(responder_name)
        rescue NameError => e
          raise NameError, "Responder not found: #{scope}::#{responder_name} (#{e.message})"
        end
      end
    end
  end

  # Routes DSL for defining application routes
  module Routes
    class RouteSet
      attr_reader :paths

      def initialize
        @paths = {}
      end

      def draw(&block)
        instance_eval(&block)
        self
      end

      # HTTP verb methods
      %i[get post put patch delete head options].each do |verb|
        define_method(verb) do |path, to:|
          add_route(path, verb, to)
        end
      end

      private

      def add_route(path, method, responder)
        route_key = "#{method.to_s.upcase} #{path}"
        
        if @paths.key?(route_key)
          raise ArgumentError, "Route already defined: #{route_key}"
        end

        @paths[route_key] = { method: method.to_s, responder: responder.to_s, path: path }
      end
    end

    def self.draw(&block)
      RouteSet.new.draw(&block)
    end
  end
end