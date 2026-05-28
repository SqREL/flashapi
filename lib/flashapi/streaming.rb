# frozen_string_literal: true

module FlashAPI
  # Streaming module provides support for streaming responses
  module Streaming
    # Frozen string constants for performance
    JSON_ARRAY_START = '['
    JSON_ARRAY_END = ']'
    JSON_SEPARATOR = ','
    NEWLINE = "\n"
    # StreamingResponse wraps an enumerable for Rack streaming
    class StreamingResponse
      include Enumerable

      def initialize(enum)
        @enum = enum
      end

      def each(&block)
        @enum.each(&block)
      end

      def close
        @enum.close if @enum.respond_to?(:close)
      end
    end

    # Module to include in responders that need streaming support
    module StreamingResponder
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def stream_response
          @streaming = true
        end

        def streaming?
          @streaming || false
        end
      end

      def streaming?
        self.class.streaming?
      end

      # Override body method to return streaming response
      def body
        if streaming? && @stream_body
          @stream_body
        else
          super
        end
      end

      # Helper method to create a streaming response
      def stream(&block)
        raise ArgumentError, 'Stream requires a block' unless block_given?
        
        @stream_body = StreamingResponse.new(Enumerator.new(&block))
      end

      # Helper to stream JSON arrays
      def stream_json_array(enumerable)
        @stream_body = StreamingResponse.new(
          Enumerator.new do |yielder|
            yielder << JSON_ARRAY_START
            first = true
            
            enumerable.each do |item|
              yielder << JSON_SEPARATOR unless first
              first = false
              yielder << JsonSerializer.dump_compact(item)
            end
            
            yielder << JSON_ARRAY_END
          end
        )
      end

      # Helper to stream NDJSON (newline-delimited JSON)
      def stream_ndjson(enumerable)
        @stream_body = StreamingResponse.new(
          Enumerator.new do |yielder|
            enumerable.each do |item|
              yielder << "#{JsonSerializer.dump_compact(item)}#{NEWLINE}"
            end
          end
        )
      end
    end
  end
end