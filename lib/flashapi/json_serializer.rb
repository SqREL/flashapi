# frozen_string_literal: true

require 'oj'

module FlashAPI
  # Optimized JSON serialization configuration
  module JsonSerializer
    # Configure Oj with optimized settings for maximum performance
    def self.configure!
      Oj.default_options = {
        # Use :strict mode for best performance
        # :rails mode provides compatibility but is slower
        mode: :strict,
        
        # Symbol keys for better performance (avoids string allocations)
        symbol_keys: true,
        
        # Disable circular reference checking for better performance
        # Only enable if you're sure there are no circular references
        circular: false,
        
        # Use faster float precision
        float_precision: 0,
        
        # Disable auto_define for better security and performance
        auto_define: false,
        
        # Use faster time format
        time_format: :ruby,
        
        # Disable BigDecimal parsing for better performance
        bigdecimal_load: :float,
        
        # Cache strings for better performance
        cache_keys: true,
        
        # Don't escape forward slashes (faster)
        escape_mode: :json,
        
        # Use integer for second precision in time
        second_precision: 0,
        
        # Don't create additions (faster and more secure)
        create_additions: false,
        
        # Use space for better performance
        space: nil,
        space_before: nil,
        object_nl: nil,
        array_nl: nil,
        
        # Faster nil handling
        nilnil: false
      }
    end
    
    # High-performance dump for API responses
    def self.dump(object)
      Oj.dump(object)
    end
    
    # Fast dump for streaming (compact mode)
    def self.dump_compact(object)
      Oj.dump(object)
    end
    
    # High-performance load with symbol keys
    def self.load(json)
      Oj.load(json)
    end
    
    # Safe load for user input (strict mode)
    def self.safe_load(json)
      Oj.safe_load(json)
    rescue Oj::ParseError => e
      raise FlashAPI::InvalidJson, "Invalid JSON: #{e.message}"
    end
  end
  
  # Exception for JSON parsing errors
  class InvalidJson < StandardError; end
end

# Configure Oj on load
FlashAPI::JsonSerializer.configure!