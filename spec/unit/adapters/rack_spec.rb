# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'json'

RSpec.describe FlashAPI::Adapters::Rack do
  include Rack::Test::Methods

  let(:test_app) do
    Module.new.tap do |mod|
      mod.const_set(:Routes, FlashAPI::Routes.draw do
        get '/hello', to: 'HelloResponder'
        post '/echo', to: 'EchoResponder'
        put '/update', to: 'UpdateResponder'
        patch '/patch', to: 'PatchResponder'
        delete '/delete', to: 'DeleteResponder'
      end)

      hello_responder = Class.new(FlashAPI::BaseResponder) do
        def call
          @render_result = ok(message: 'Hello from Rack!')
        end
      end
      mod.const_set(:HelloResponder, hello_responder)

      echo_responder = Class.new(FlashAPI::BaseResponder) do
        def call
          @render_result = ok(received: params)
        end
      end
      mod.const_set(:EchoResponder, echo_responder)

      update_responder = Class.new(FlashAPI::BaseResponder) do
        def call
          @render_result = ok(method: 'PUT', body: params)
        end
      end
      mod.const_set(:UpdateResponder, update_responder)

      patch_responder = Class.new(FlashAPI::BaseResponder) do
        def call
          @render_result = ok(method: 'PATCH', body: params)
        end
      end
      mod.const_set(:PatchResponder, patch_responder)

      delete_responder = Class.new(FlashAPI::BaseResponder) do
        def call
          @render_result = no_content
        end
      end
      mod.const_set(:DeleteResponder, delete_responder)
    end
  end

  let(:adapter) { described_class.new(test_app) }
  let(:app) { adapter }

  describe '.build_app' do
    it 'creates a new instance of the adapter' do
      app = described_class.build_app(test_app, port: 4000)
      expect(app).to be_a(described_class)
      expect(app.options[:port]).to eq(4000)
    end
  end

  describe '#call' do
    context 'with GET request' do
      it 'processes the request and returns Rack response' do
        get '/hello'
        
        expect(last_response.status).to eq(200)
        expect(last_response.headers['Content-Type']).to eq('application/json')
        
        body = Oj.load(last_response.body, symbol_keys: true)
        expect(body).to include(
          status_code: 200,
          success: true,
          message: 'Hello from Rack!'
        )
      end
    end

    context 'with POST request and JSON body' do
      it 'processes the request with body content' do
        post '/echo', { name: 'Test', value: 42 }.to_json, { 'CONTENT_TYPE' => 'application/json' }
        
        expect(last_response.status).to eq(200)
        
        body = Oj.load(last_response.body, symbol_keys: true)
        expect(body[:received]).to include(
          name: 'Test',
          value: 42
        )
      end
    end

    context 'with PUT request' do
      it 'handles PUT requests correctly' do
        put '/update', { id: 1, data: 'updated' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
        
        expect(last_response.status).to eq(200)
        
        body = Oj.load(last_response.body, symbol_keys: true)
        expect(body[:method]).to eq('PUT')
        expect(body[:body]).to include(id: 1, data: 'updated')
      end
    end

    context 'with PATCH request' do
      it 'handles PATCH requests correctly' do
        patch '/patch', { field: 'value' }.to_json, { 'CONTENT_TYPE' => 'application/json' }
        
        expect(last_response.status).to eq(200)
        
        body = Oj.load(last_response.body, symbol_keys: true)
        expect(body[:method]).to eq('PATCH')
        expect(body[:body]).to include(field: 'value')
      end
    end

    context 'with DELETE request' do
      it 'handles DELETE requests correctly' do
        delete '/delete'
        
        expect(last_response.status).to eq(204)
        
        body = Oj.load(last_response.body, symbol_keys: true)
        expect(body).to include(
          status_code: 204,
          success: true
        )
      end
    end

    context 'with non-existent route' do
      it 'returns 404 error' do
        get '/nonexistent'
        
        expect(last_response.status).to eq(404)
        
        body = Oj.load(last_response.body, symbol_keys: true)
        expect(body).to include(
          status_code: 404,
          success: false,
          error: /No route found/
        )
      end
    end

    context 'with headers' do
      it 'extracts HTTP headers correctly' do
        header 'X-Custom-Header', 'test-value'
        header 'Authorization', 'Bearer token123'
        
        get '/hello'
        
        expect(last_response.status).to eq(200)
      end
    end

    context 'with query parameters' do
      it 'preserves query string' do
        get '/hello?foo=bar&baz=qux'
        
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe '#build_request' do
    let(:env) do
      {
        'REQUEST_METHOD' => 'POST',
        'PATH_INFO' => '/test',
        'QUERY_STRING' => 'foo=bar',
        'CONTENT_TYPE' => 'application/json',
        'HTTP_X_CUSTOM_HEADER' => 'value',
        'HTTP_AUTHORIZATION' => 'Bearer token',
        'CONTENT_LENGTH' => '13',
        'rack.url_scheme' => 'https',
        'rack.input' => StringIO.new('{"key":"val"}')
      }
    end

    it 'builds BaseRequest from Rack env' do
      request = adapter.send(:build_request, env)

      expect(request).to be_a(FlashAPI::BaseRequest)
      expect(request.protocol).to eq('https')
      expect(request.request_method).to eq('POST')
      expect(request.path_info).to eq('/test')
      expect(request.uri).to eq('/test')
      expect(request.query_string).to eq('foo=bar')
      expect(request.content_type).to eq('application/json')
      expect(request.post_content).to eq('{"key":"val"}')
    end

    it 'extracts headers correctly' do
      request = adapter.send(:build_request, env)
      
      expect(request.headers).to include(
        'X-Custom-Header' => 'value',
        'Authorization' => 'Bearer token',
        'Content-Type' => 'application/json',
        'Content-Length' => '13'
      )
    end

    context 'with GET request' do
      let(:env) do
        {
          'REQUEST_METHOD' => 'GET',
          'PATH_INFO' => '/test',
          'rack.url_scheme' => 'http',
          'rack.input' => StringIO.new('')
        }
      end

      it 'does not read body for GET requests' do
        request = adapter.send(:build_request, env)
        expect(request.post_content).to be_nil
      end
    end
  end

  describe '#start and #stop' do
    it 'has start method' do
      expect(adapter).to respond_to(:start)
    end

    it 'has stop method' do
      expect(adapter).to respond_to(:stop)
    end
  end

  describe 'server configuration' do
    it 'stores default options when none provided' do
      expect(adapter.options).to eq({})
    end

    it 'stores custom server options' do
      custom_adapter = described_class.new(test_app, 
        port: 8080,
        host: 'localhost',
        server: 'puma',
        environment: 'production'
      )

      expect(custom_adapter.options).to include(
        port: 8080,
        host: 'localhost',
        server: 'puma',
        environment: 'production'
      )
    end
  end

  describe 'object pooling optimization' do
    context 'with pooling enabled (default)' do
      it 'uses pooled request objects' do
        expect(FlashAPI::Adapters::Rack::RACK_REQUEST_POOL).to receive(:with_request).and_call_original
        expect(FlashAPI::Adapters::Rack::BASE_REQUEST_POOL).to receive(:build_request).and_call_original
        
        get '/hello'
        expect(last_response.status).to eq(200)
      end

      it 'handles concurrent requests with pooling' do
        threads = 10.times.map do
          Thread.new do
            env = Rack::MockRequest.env_for('/hello')
            status, _headers, _body = adapter.call(env)
            expect(status).to eq(200)
          end
        end
        
        threads.each(&:join)
      end
    end

    context 'with pooling disabled' do
      let(:adapter) { described_class.new(test_app, use_pooling: false) }

      it 'uses standard request objects' do
        expect(FlashAPI::Adapters::Rack::RACK_REQUEST_POOL).not_to receive(:with_request)
        expect(FlashAPI::Adapters::Rack::BASE_REQUEST_POOL).not_to receive(:build_request)
        
        get '/hello'
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe 'integration with FlashAPI error handling' do
    context 'when responder raises an error' do
      let(:error_app) do
        Module.new.tap do |mod|
          mod.const_set(:Routes, FlashAPI::Routes.draw do
            get '/error', to: 'ErrorResponder'
          end)

          error_responder = Class.new(FlashAPI::BaseResponder) do
            def call
              raise StandardError, 'Something went wrong'
            end
          end
          mod.const_set(:ErrorResponder, error_responder)
        end
      end

      let(:adapter) { described_class.new(error_app) }

      it 'returns 500 error response' do
        get '/error'
        
        expect(last_response.status).to eq(500)
        
        body = Oj.load(last_response.body, symbol_keys: true)
        expect(body).to include(
          status_code: 500,
          success: false,
          error: /Internal Server Error: Something went wrong/
        )
      end
    end
  end
end