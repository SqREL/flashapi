# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FlashAPI do
  describe '.VERSION' do
    it 'has a version number' do
      expect(FlashAPI::VERSION).to be_a(String)
      expect(FlashAPI::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe 'exception hierarchy' do
    it 'defines proper exception inheritance' do
      expect(FlashAPI::Error).to be < StandardError
      expect(FlashAPI::NoRouteMatch).to be < FlashAPI::Error
      expect(FlashAPI::AdapterNotFound).to be < FlashAPI::Error
    end
  end

  describe '.start' do
    let(:app) { Module.new }
    let(:adapter_instance) { instance_double('Adapter', start: nil) }
    let(:adapter_class) { class_double('AdapterClass', new: adapter_instance) }

    before do
      allow(FlashAPI::Adapters).to receive(:get).with(:rack).and_return(adapter_class)
    end

    it 'creates and starts an adapter with default options' do
      server = described_class.start(app)
      
      expect(FlashAPI::Adapters).to have_received(:get).with(:rack)
      expect(adapter_class).to have_received(:new).with(app)
      expect(adapter_instance).to have_received(:start)
      expect(server).to eq(adapter_instance)
    end

    it 'accepts custom adapter and options' do
      allow(FlashAPI::Adapters).to receive(:get).with(:eventmachine).and_return(adapter_class)
      
      described_class.start(app, adapter: :eventmachine, port: 8080)
      
      expect(adapter_class).to have_received(:new).with(app, port: 8080)
    end

    context 'when adapter is not found' do
      before do
        allow(FlashAPI::Adapters).to receive(:get).and_raise(FlashAPI::AdapterNotFound, 'Not found')
      end

      it 'lets the exception bubble up' do
        expect { described_class.start(app, adapter: :nonexistent) }
          .to raise_error(FlashAPI::AdapterNotFound)
      end
    end
  end

  describe '.rack_app' do
    let(:app) { Module.new }
    let(:rack_app_instance) { instance_double('RackApp') }

    before do
      allow(FlashAPI::Adapters::Rack).to receive(:build_app).and_return(rack_app_instance)
    end

    it 'builds a Rack-compatible app' do
      result = described_class.rack_app(app, port: 3000)
      
      expect(FlashAPI::Adapters::Rack).to have_received(:build_app).with(app, port: 3000)
      expect(result).to eq(rack_app_instance)
    end
  end

  # Integration test demonstrating the full framework
  describe 'end-to-end integration' do
    let(:test_app) do
      Module.new.tap do |mod|
        # Define routes using the new DSL
        mod.const_set(:Routes, FlashAPI::Routes.draw do
          get '/hello', to: 'HelloResponder'
          post '/echo', to: 'EchoResponder'
          get '/status', to: 'StatusResponder'
        end)

        # Define responders
        hello_responder = Class.new(FlashAPI::BaseResponder) do
          def call
            @render_result = ok(message: 'Hello, World!', timestamp: Time.now.iso8601)
          end
        end
        mod.const_set(:HelloResponder, hello_responder)

        echo_responder = Class.new(FlashAPI::BaseResponder) do
          def call
            @render_result = case params
            in { message: String => msg } if msg.length > 0
              ok(echo: msg, length: msg.length)
            else
              bad_request('Message parameter is required and cannot be empty')
            end
          end
        end
        mod.const_set(:EchoResponder, echo_responder)

        status_responder = Class.new(FlashAPI::BaseResponder) do
          def call
            @render_result = ok(
              status: 'healthy',
              uptime: '1d 2h 3m',
              version: FlashAPI::VERSION,
              request_info: {
                method: request.request_method,
                uri: request.uri,
                headers_count: request.headers.size
              }
            )
          end
        end
        mod.const_set(:StatusResponder, status_responder)
      end
    end

    describe 'GET /hello endpoint' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/hello',
          request_method: 'GET',
          headers: { 'User-Agent' => 'RSpec' }
        )
      end

      it 'returns successful hello response' do
        responder_class = FlashAPI::Application.run(request, test_app)
        responder = responder_class.new(request)
        responder.call

        expect(responder.status_code).to eq(200)
        expect(responder.body).to be_success_response
        
        parsed_body = Oj.load(responder.body, symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 200,
          success: true,
          message: 'Hello, World!'
        )
        expect(parsed_body[:timestamp]).not_to be_nil
      end
    end

    describe 'POST /echo endpoint' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/echo',
          request_method: 'POST',
          content_type: 'application/json',
          post_content: '{"message":"Test message"}',
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'echoes the message back with additional info' do
        responder_class = FlashAPI::Application.run(request, test_app)
        responder = responder_class.new(request)
        responder.call

        expect(responder.status_code).to eq(200)
        expect(responder.body).to be_success_response
        
        parsed_body = Oj.load(responder.body, symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 200,
          success: true,
          echo: 'Test message',
          length: 12
        )
      end

      context 'with missing message parameter' do
        let(:request) do
          FlashAPI::BaseRequest.new(
            uri: '/echo',
            request_method: 'POST',
            content_type: 'application/json',
            post_content: '{}',
            headers: { 'Content-Type' => 'application/json' }
          )
        end

        it 'returns bad request error' do
          responder_class = FlashAPI::Application.run(request, test_app)
          responder = responder_class.new(request)
          responder.call

          expect(responder.status_code).to eq(400)
          expect(responder.body).to be_error_response(400)
          
          parsed_body = Oj.load(responder.body, symbol_keys: true)
          expect(parsed_body[:error]).to include('Message parameter is required')
        end
      end

      context 'with empty message' do
        let(:request) do
          FlashAPI::BaseRequest.new(
            uri: '/echo',
            request_method: 'POST',
            content_type: 'application/json',
            post_content: '{"message":""}',
            headers: { 'Content-Type' => 'application/json' }
          )
        end

        it 'returns bad request error' do
          responder_class = FlashAPI::Application.run(request, test_app)
          responder = responder_class.new(request)
          responder.call

          expect(responder.status_code).to eq(400)
          expect(responder.body).to be_error_response(400)
        end
      end
    end

    describe 'GET /status endpoint' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/status',
          request_method: 'GET',
          query_string: 'format=json&verbose=true',
          headers: { 'User-Agent' => 'RSpec', 'Accept' => 'application/json' }
        )
      end

      it 'returns comprehensive status information' do
        responder_class = FlashAPI::Application.run(request, test_app)
        responder = responder_class.new(request)
        responder.call

        expect(responder.status_code).to eq(200)
        expect(responder.body).to be_success_response
        
        parsed_body = Oj.load(responder.body, symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 200,
          success: true,
          status: 'healthy',
          uptime: '1d 2h 3m',
          version: FlashAPI::VERSION
        )
        
        expect(parsed_body[:request_info]).to include(
          method: 'GET',
          uri: '/status',
          headers_count: 2
        )
      end
    end

    describe 'route not found' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/nonexistent',
          request_method: 'GET'
        )
      end

      it 'raises NoRouteMatch with descriptive message' do
        expect { FlashAPI::Application.run(request, test_app) }
          .to raise_error(FlashAPI::NoRouteMatch, /No route found for: \/nonexistent/)
      end
    end

    describe 'method not allowed' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/hello',
          request_method: 'POST'  # Only GET is allowed
        )
      end

      it 'raises NoRouteMatch with method not allowed message' do
        expect { FlashAPI::Application.run(request, test_app) }
          .to raise_error(FlashAPI::NoRouteMatch, /Method not allowed: POST for \/hello/)
      end
    end
  end
end