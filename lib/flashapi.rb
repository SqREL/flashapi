# frozen_string_literal: true

require 'oj'

require_relative 'flashapi/version'
require_relative 'flashapi/responder'
require_relative 'flashapi/application'
require_relative 'flashapi/base_request'
require_relative 'flashapi/adapters'
require_relative 'flashapi/adapters/rack'
require_relative 'flashapi/adapters/event_machine'

module FlashAPI
  class Error < StandardError; end
  class NoRouteMatch < Error; end
  class AdapterNotFound < Error; end

  class << self
    # Start a FlashAPI server with the specified adapter
    def start(app, adapter: :rack, **options)
      adapter_class = Adapters.get(adapter)
      server = adapter_class.new(app, **options)
      server.start
      server
    end

    # Build a Rack-compatible app (useful for config.ru)
    def rack_app(app, **options)
      Adapters::Rack.build_app(app, **options)
    end
  end
end
