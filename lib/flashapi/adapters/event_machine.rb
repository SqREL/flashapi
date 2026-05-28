# frozen_string_literal: true

require 'eventmachine'
require 'http_parser.rb'

module FlashAPI
  module Adapters
    # EventMachine adapter for high-performance async HTTP server
    class EventMachine < Base
      # Frozen string constants for performance
      CONTENT_TYPE = 'Content-Type'
      APPLICATION_JSON = 'application/json'
      COOKIE = 'Cookie'
      CONTENT_LENGTH = 'Content-Length'
      CONNECTION = 'Connection'
      KEEP_ALIVE = 'keep-alive'
      CLOSE = 'close'
      HTTP_1_1 = 'HTTP/1.1 '
      CRLF = "\r\n"
      HEADER_SEPARATOR = ': '
      COOKIE_SEPARATOR = ';'
      COOKIE_VALUE_SEPARATOR = '='
      SPACE = ' '
      DEFAULT_OPTIONS = {
        host: '0.0.0.0',
        port: 3000,
        backlog: 1024
      }.freeze

      def start
        ensure_event_machine_running do
          @server = ::EventMachine.start_server(
            options[:host] || DEFAULT_OPTIONS[:host],
            options[:port] || DEFAULT_OPTIONS[:port],
            Connection,
            self
          )
          
          puts "FlashAPI EventMachine server running on #{options[:host]}:#{options[:port]}"
        end
      end

      def stop
        ::EventMachine.stop_server(@server) if @server
        ::EventMachine.stop if ::EventMachine.reactor_running?
      end

      private

      def ensure_event_machine_running(&block)
        if ::EventMachine.reactor_running?
          block.call
        else
          ::EventMachine.run(&block)
        end
      end

      # EventMachine connection handler
      class Connection < ::EventMachine::Connection
        include ::EventMachine::Protocols::LineText2

        attr_reader :adapter, :parser, :request_data

        def initialize(adapter)
          @adapter = adapter
          @parser = Http::Parser.new(self)
          @request_data = {}
          @body = []
        end

        def receive_data(data)
          parser << data
        rescue Http::Parser::Error => e
          send_error_response(400, "Bad Request: #{e.message}")
          close_connection_after_writing
        end

        # HTTP Parser callbacks
        def on_message_begin
          @request_data = { headers: {} }
          @body = []
        end

        def on_headers_complete(headers)
          @request_data[:headers] = headers
        end

        def on_body(chunk)
          @body << chunk
        end

        def on_message_complete
          @request_data[:body] = @body.join
          process_request
        end

        def on_url(url)
          @request_data[:url] = url
          uri = URI.parse(url)
          @request_data[:path] = uri.path
          @request_data[:query_string] = uri.query
        rescue URI::InvalidURIError
          @request_data[:path] = url
          @request_data[:query_string] = nil
        end

        private

        def process_request
          request = build_request
          response = adapter.send(:handle_request, request)
          
          send_response(response)
          close_connection_after_writing unless keep_alive?
        end

        def build_request
          BaseRequest.new(
            protocol: 'http',
            request_method: parser.http_method,
            cookie: extract_cookies,
            content_type: request_data[:headers][CONTENT_TYPE],
            path_info: request_data[:path],
            uri: request_data[:path],
            query_string: request_data[:query_string],
            post_content: request_data[:body],
            headers: request_data[:headers]
          )
        end

        def extract_cookies
          cookie_header = request_data[:headers][COOKIE]
          return {} unless cookie_header

          cookie_header.split(COOKIE_SEPARATOR).each_with_object({}) do |cookie, hash|
            key, value = cookie.strip.split(COOKIE_VALUE_SEPARATOR, 2)
            hash[key] = value if key && value
          end
        end

        def send_response(response)
          status_line = "#{HTTP_1_1}#{response[:status]} #{http_status_text(response[:status])}#{CRLF}"
          headers = build_response_headers(response[:headers], response[:body])
          
          send_data(status_line)
          send_data(headers)
          send_data(CRLF)
          send_data(response[:body])
        end

        def build_response_headers(headers, body)
          headers = headers.dup
          headers[CONTENT_LENGTH] = body.bytesize.to_s
          headers[CONNECTION] = keep_alive? ? KEEP_ALIVE : CLOSE
          
          headers.map { |k, v| "#{k}#{HEADER_SEPARATOR}#{v}" }.join(CRLF)
        end

        def send_error_response(status, message)
          body = JsonSerializer.dump({ status_code: status, success: false, error: message })
          response = {
            status:,
            headers: { CONTENT_TYPE => APPLICATION_JSON },
            body:
          }
          send_response(response)
        end

        def keep_alive?
          return false unless parser.http_version == [1, 1]
          
          connection_header = request_data[:headers][CONNECTION]&.downcase
          connection_header != CLOSE
        end

        def http_status_text(status)
          case status
          when 200 then 'OK'
          when 201 then 'Created'
          when 204 then 'No Content'
          when 400 then 'Bad Request'
          when 401 then 'Unauthorized'
          when 403 then 'Forbidden'
          when 404 then 'Not Found'
          when 422 then 'Unprocessable Entity'
          when 500 then 'Internal Server Error'
          else 'Unknown'
          end
        end
      end
    end

    # Register the EventMachine adapter
    register(:eventmachine, EventMachine)
    register(:em, EventMachine) # Alias
  end
end