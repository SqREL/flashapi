# frozen_string_literal: true

module FlashAPI
  # Thread-safe object pool for reusing objects and reducing GC pressure
  class ObjectPool
    def initialize(size: 100, &factory)
      raise ArgumentError, 'Factory block required' unless block_given?
      
      @factory = factory
      @size = size
      @pool = []
      @mutex = Mutex.new
      @available = ConditionVariable.new
      
      # Pre-populate pool
      size.times { @pool << @factory.call }
    end

    # Borrow an object from the pool
    def borrow(timeout: nil)
      @mutex.synchronize do
        while @pool.empty?
          if timeout
            return nil unless @available.wait(@mutex, timeout)
          else
            @available.wait(@mutex)
          end
        end
        @pool.pop
      end
    end

    # Return an object to the pool
    def return_object(obj)
      @mutex.synchronize do
        if @pool.size < @size
          reset_object(obj)
          @pool.push(obj)
          @available.signal
        end
      end
    end

    # Borrow an object, use it in a block, and automatically return it
    def with_object
      obj = borrow
      result = yield obj
      result
    ensure
      return_object(obj) if obj
    end

    private

    def reset_object(obj)
      # Subclasses can override to provide custom reset logic
      obj.reset if obj.respond_to?(:reset)
    end
  end

  # Poolable module for objects that can be pooled
  module Poolable
    def reset
      # Default implementation - subclasses should override
      instance_variables.each do |var|
        instance_variable_set(var, nil)
      end
    end
  end

  # Specialized pool for Rack request wrappers
  class RackRequestPool < ObjectPool
    class PooledRackRequest
      include Poolable

      attr_accessor :env

      def initialize
        @env = nil
      end

      def reset
        @env = nil
      end

      # Delegate all method calls to the actual Rack::Request
      def method_missing(method, *args, &block)
        rack_request.send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        rack_request.respond_to?(method, include_private)
      end

      private

      def rack_request
        @rack_request ||= ::Rack::Request.new(@env)
      end
    end

    def initialize(size: 100)
      super(size: size) { PooledRackRequest.new }
    end

    def with_request(env)
      with_object do |request|
        request.env = env
        request.instance_variable_set(:@rack_request, nil) # Reset cached rack_request
        yield request
      end
    end
  end

  # Pool for BaseRequest objects
  class BaseRequestPool < ObjectPool
    # Since BaseRequest is immutable (Data class), we can't pool it directly
    # Instead, we'll pool the hash builders
    class RequestBuilder
      include Poolable

      attr_reader :attributes

      def initialize
        reset
      end

      def reset
        @attributes = {
          protocol: nil,
          request_method: nil,
          cookie: nil,
          content_type: nil,
          path_info: nil,
          uri: nil,
          query_string: nil,
          post_content: nil,
          headers: nil
        }
      end

      def set(key, value)
        @attributes[key] = value
        self
      end

      def build
        BaseRequest.new(**@attributes)
      end
    end

    def initialize(size: 100)
      super(size: size) { RequestBuilder.new }
    end

    def build_request(&block)
      with_object do |builder|
        yield builder
        builder.build
      end
    end
  end
end