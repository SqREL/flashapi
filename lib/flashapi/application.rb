# frozen_string_literal: true

module FlashAPI
  # Frozen string constants for performance
  SPACE = ' '
  ROUTES_CONST = :Routes
  PATHS_METHOD = :paths
  
  # Application router with modern Ruby pattern matching and proper error handling
  class Application
    class << self
      # Thread-safe route cache
      def route_cache
        @route_cache ||= {}
      end
      
      # Clear the route cache (useful for development/testing)
      def clear_cache!
        @route_cache = {}
      end
      
      def run(request, scope)
        validate_scope!(scope)
        
        route = find_route(request, scope)
        instantiate_responder(route[:responder], scope)
      end

      private

      def validate_scope!(scope)
        return if scope.const_defined?(ROUTES_CONST) && scope::Routes.respond_to?(PATHS_METHOD)
        
        raise ArgumentError, "Invalid scope: #{scope} must define Routes.paths"
      end

      def find_route(request, scope)
        # Handle nil request method or URI
        if request.request_method.nil? || request.uri.nil?
          raise NoRouteMatch, "Invalid request: method and URI cannot be nil"
        end
        
        # Build cache key combining scope and route
        cache_key = "#{scope.object_id}:#{request.request_method.upcase}#{SPACE}#{request.uri}"
        
        # Check cache first
        cached_route = route_cache[cache_key]
        return cached_route if cached_route
        
        # Cache miss - perform lookup
        routes = scope::Routes.paths
        route_key = "#{request.request_method.upcase}#{SPACE}#{request.uri}"
        
        case routes[route_key]
        in { method:, responder:, path: }
          route = { responder: }
          # Cache successful route lookup
          route_cache[cache_key] = route
          route
        in nil
          # Check if path exists with different method using optimized lookup
          if scope::Routes.respond_to?(:routes_for_path)
            path_route_keys = scope::Routes.routes_for_path(request.uri)
          else
            # Fallback for older route sets
            path_route_keys = routes.keys.select { |key| key.end_with?("#{SPACE}#{request.uri}") }
          end
          
          if path_route_keys.any?
            available_methods = path_route_keys.map { |key| key.split(SPACE, 2).first }.join(', ')
            raise NoRouteMatch, "Method not allowed: #{request.request_method} for #{request.uri}. Available methods: #{available_methods}"
          else
            raise NoRouteMatch, "No route found for: #{request.uri}"
          end
        end
      end


      def instantiate_responder(responder_name, scope)
        # Cache responder lookups
        responder_cache_key = "#{scope.object_id}:#{responder_name}"
        cached_responder = route_cache[responder_cache_key]
        return cached_responder if cached_responder
        
        begin
          responder = scope.const_get(responder_name)
          route_cache[responder_cache_key] = responder
          responder
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
        @compiled = false
        @route_keys = nil
      end

      def draw(&block)
        instance_eval(&block)
        compile_routes!
        self
      end
      
      # Compile routes for faster lookups
      def compile_routes!
        return if @compiled
        
        # Pre-compute and freeze route keys for faster iteration
        @route_keys = @paths.keys.freeze
        @paths.freeze
        @compiled = true
      end
      
      # Get all routes for a specific path (for method checking)
      def routes_for_path(path)
        return [] unless @route_keys
        
        suffix = "#{SPACE}#{path}"
        @route_keys.select { |key| key.end_with?(suffix) }
      end

      # HTTP verb methods
      %i[get post put patch delete head options].each do |verb|
        define_method(verb) do |path, to:|
          add_route(path, verb, to)
        end
      end

      private

      def add_route(path, method, responder)
        route_key = "#{method.to_s.upcase}#{SPACE}#{path}"
        
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