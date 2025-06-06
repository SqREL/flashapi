# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FlashAPI::Adapters do
  describe '.register' do
    after { described_class.instance_variable_set(:@adapters, nil) }

    it 'registers an adapter class with symbol name' do
      adapter_class = Class.new
      described_class.register(:test_adapter, adapter_class)
      
      expect(described_class.get(:test_adapter)).to eq(adapter_class)
    end

    it 'converts string names to symbols' do
      adapter_class = Class.new
      described_class.register('string_adapter', adapter_class)
      
      expect(described_class.get(:string_adapter)).to eq(adapter_class)
    end

    it 'allows overwriting existing adapters' do
      old_adapter = Class.new
      new_adapter = Class.new
      
      described_class.register(:overwrite_test, old_adapter)
      described_class.register(:overwrite_test, new_adapter)
      
      expect(described_class.get(:overwrite_test)).to eq(new_adapter)
    end
  end

  describe '.get' do
    before do
      @test_adapter = Class.new
      @another_adapter = Class.new
      described_class.register(:registered_adapter, @test_adapter)
      described_class.register(:another_adapter, @another_adapter)
    end

    after { described_class.instance_variable_set(:@adapters, nil) }

    it 'retrieves registered adapter by symbol' do
      expect(described_class.get(:registered_adapter)).to eq(@test_adapter)
    end

    it 'retrieves registered adapter by string' do
      expect(described_class.get('registered_adapter')).to eq(@test_adapter)
    end

    it 'raises AdapterNotFound for unregistered adapter' do
      expect { described_class.get(:nonexistent) }
        .to raise_error(FlashAPI::AdapterNotFound, /Adapter 'nonexistent' not found/)
    end

    it 'includes available adapters in error message' do
      expect { described_class.get(:missing) }
        .to raise_error(FlashAPI::AdapterNotFound, /Available adapters: .*registered_adapter.*another_adapter/)
    end

    it 'handles case when no adapters are registered' do
      described_class.instance_variable_set(:@adapters, {})
      
      expect { described_class.get(:any) }
        .to raise_error(FlashAPI::AdapterNotFound, /Available adapters: $/)
    end
  end

  describe '.available_adapters' do
    before do
      described_class.register(:first_adapter, Class.new)
      described_class.register(:second_adapter, Class.new)
      described_class.register(:third_adapter, Class.new)
    end

    after { described_class.instance_variable_set(:@adapters, nil) }

    it 'returns array of registered adapter names as symbols' do
      adapters = described_class.available_adapters
      # Check that our test adapters are included, but allow for pre-registered adapters
      expect(adapters).to include(:first_adapter, :second_adapter, :third_adapter)
      expect(adapters).to all(be_a(Symbol))
    end

    it 'returns empty array when no adapters registered' do
      described_class.instance_variable_set(:@adapters, {})
      expect(described_class.available_adapters).to eq([])
    end
  end

  describe 'adapter registry isolation' do
    after { described_class.instance_variable_set(:@adapters, nil) }

    it 'maintains separate adapter registry' do
      described_class.register(:test1, Class.new)
      
      # Create new instance to verify class-level storage
      expect(described_class.get(:test1)).to be_a(Class)
    end

    it 'persists adapters across multiple calls' do
      adapter_class = Class.new
      described_class.register(:persistent, adapter_class)
      
      # Multiple calls should return same adapter
      expect(described_class.get(:persistent)).to eq(adapter_class)
      expect(described_class.get(:persistent)).to eq(adapter_class)
    end
  end
end

RSpec.describe FlashAPI::Adapters::Base do
  let(:app) { Module.new }
  let(:options) { { port: 3000, host: '127.0.0.1', debug: true } }
  
  subject(:adapter) { described_class.new(app, **options) }

  describe '#initialize' do
    it 'stores app reference' do
      expect(adapter.app).to eq(app)
    end

    it 'stores options hash' do
      expect(adapter.options).to eq(options)
    end

    it 'handles empty options' do
      adapter = described_class.new(app)
      expect(adapter.options).to eq({})
    end

    it 'accepts keyword arguments' do
      adapter = described_class.new(app, port: 8080, ssl: true)
      expect(adapter.options).to include(port: 8080, ssl: true)
    end
  end

  describe '#start' do
    it 'raises NotImplementedError with helpful message' do
      expect { adapter.start }.to raise_error(
        NotImplementedError,
        /must implement #start method/
      )
    end
  end

  describe '#stop' do
    it 'raises NotImplementedError with helpful message' do
      expect { adapter.stop }.to raise_error(
        NotImplementedError,
        /must implement #stop method/
      )
    end
  end

  describe '#handle_request (private method)' do
    let(:request) { instance_double(FlashAPI::BaseRequest) }
    let(:responder) { instance_double('Responder', status_code: 200, headers: {}, body: '{"test":true}') }
    let(:responder_class) { class_double('ResponderClass', new: responder) }

    before do
      allow(FlashAPI::Application).to receive(:run).with(request, app).and_return(responder_class)
    end

    it 'processes request and returns response hash' do
      response = adapter.send(:handle_request, request)
      
      expect(response).to include(
        status: 200,
        headers: {},
        body: '{"test":true}'
      )
      expect(FlashAPI::Application).to have_received(:run).with(request, app)
      expect(responder_class).to have_received(:new).with(request)
    end

    context 'when responder implements call method' do
      let(:callable_responder) do
        instance_double('CallableResponder',
          call: nil,
          status_code: 201,
          headers: { 'Content-Type' => 'application/json' },
          body: '{"created":true}'
        )
      end
      let(:responder_class) { class_double('ResponderClass', new: callable_responder) }

      before do
        allow(callable_responder).to receive(:respond_to?).with(:call).and_return(true)
      end

      it 'calls the responder method' do
        response = adapter.send(:handle_request, request)
        
        expect(callable_responder).to have_received(:call)
        expect(response).to include(
          status: 201,
          headers: { 'Content-Type' => 'application/json' },
          body: '{"created":true}'
        )
      end
    end

    context 'when responder does not implement call method' do
      before do
        allow(responder).to receive(:respond_to?).with(:call).and_return(false)
      end

      it 'uses responder directly without calling call method' do
        response = adapter.send(:handle_request, request)
        
        expect(responder).not_to have_received(:call) if responder.respond_to?(:call)
        expect(response).to include(status: 200)
      end
    end

    context 'when NoRouteMatch is raised' do
      before do
        allow(FlashAPI::Application).to receive(:run).and_raise(
          FlashAPI::NoRouteMatch, 'No route found for /missing'
        )
      end

      it 'returns 404 error response' do
        response = adapter.send(:handle_request, request)
        
        expect(response).to include(status: 404)
        
        parsed_body = Oj.load(response[:body], symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 404,
          success: false,
          error: 'No route found for /missing'
        )
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(FlashAPI::Application).to receive(:run).and_raise(
          StandardError, 'Database connection failed'
        )
      end

      it 'returns 500 error response' do
        response = adapter.send(:handle_request, request)
        
        expect(response).to include(status: 500)
        
        parsed_body = Oj.load(response[:body], symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 500,
          success: false
        )
        expect(parsed_body[:error]).to include('Internal Server Error')
      end
    end

    context 'when responder instantiation fails' do
      before do
        allow(responder_class).to receive(:new).and_raise(ArgumentError, 'Invalid arguments')
      end

      it 'returns 500 error response' do
        response = adapter.send(:handle_request, request)
        
        expect(response).to include(status: 500)
        
        parsed_body = Oj.load(response[:body], symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 500,
          success: false
        )
      end
    end
  end

  describe '#error_response (private method)' do
    it 'creates properly formatted error response' do
      response = adapter.send(:error_response, 422, 'Validation failed')
      
      expect(response).to include(
        status: 422,
        headers: { 'Content-Type' => 'application/json' }
      )
      
      parsed_body = Oj.load(response[:body], symbol_keys: true)
      expect(parsed_body).to include(
        status_code: 422,
        success: false,
        error: 'Validation failed'
      )
    end

    it 'handles empty error message' do
      response = adapter.send(:error_response, 500, '')
      
      parsed_body = Oj.load(response[:body], symbol_keys: true)
      expect(parsed_body[:error]).to eq('')
    end

    it 'handles nil error message' do
      response = adapter.send(:error_response, 400, nil)
      
      parsed_body = Oj.load(response[:body], symbol_keys: true)
      expect(parsed_body[:error]).to be_nil
    end
  end

  describe 'integration with real components' do
    let(:test_app) do
      Module.new.tap do |mod|
        routes = FlashAPI::Routes.draw do
          get '/test', to: 'TestController'
          post '/echo', to: 'EchoController'
        end
        mod.const_set(:Routes, routes)

        test_controller = Class.new(FlashAPI::BaseResponder) do
          def call
            @render_result = ok(message: 'Test successful', timestamp: Time.now.iso8601)
          end
        end
        mod.const_set(:TestController, test_controller)

        echo_controller = Class.new(FlashAPI::BaseResponder) do
          def call
            @render_result = case params
            in { text: String => message }
              ok(echo: message, length: message.length)
            else
              bad_request('Text parameter is required')
            end
          end
        end
        mod.const_set(:EchoController, echo_controller)
      end
    end

    let(:adapter) { described_class.new(test_app, port: 3000) }

    context 'with successful GET request' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/test',
          request_method: 'GET',
          headers: { 'Accept' => 'application/json' }
        )
      end

      it 'processes request end-to-end' do
        response = adapter.send(:handle_request, request)
        
        expect(response[:status]).to eq(200)
        expect(response[:headers]).to eq('Content-Type' => 'application/json')
        
        parsed_body = Oj.load(response[:body], symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 200,
          success: true,
          message: 'Test successful'
        )
        expect(parsed_body[:timestamp]).not_to be_nil
      end
    end

    context 'with successful POST request' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/echo',
          request_method: 'POST',
          content_type: 'application/json',
          post_content: '{"text":"Hello, World!"}',
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'processes POST request with JSON body' do
        response = adapter.send(:handle_request, request)
        
        expect(response[:status]).to eq(200)
        
        parsed_body = Oj.load(response[:body], symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 200,
          success: true,
          echo: 'Hello, World!',
          length: 13
        )
      end
    end

    context 'with POST request missing required parameter' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/echo',
          request_method: 'POST',
          content_type: 'application/json',
          post_content: '{}',
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'handles validation errors correctly' do
        response = adapter.send(:handle_request, request)
        
        expect(response[:status]).to eq(400)
        
        parsed_body = Oj.load(response[:body], symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 400,
          success: false,
          error: 'Text parameter is required'
        )
      end
    end

    context 'with request to non-existent route' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          uri: '/nonexistent',
          request_method: 'GET'
        )
      end

      it 'handles route not found' do
        response = adapter.send(:handle_request, request)
        
        expect(response[:status]).to eq(404)
        
        parsed_body = Oj.load(response[:body], symbol_keys: true)
        expect(parsed_body).to include(
          status_code: 404,
          success: false
        )
        expect(parsed_body[:error]).to include('No route found')
      end
    end
  end

  describe 'adapter lifecycle' do
    it 'can be created with minimal configuration' do
      minimal_adapter = described_class.new(Module.new)
      expect(minimal_adapter.app).to be_a(Module)
      expect(minimal_adapter.options).to eq({})
    end

    it 'stores complex configuration options' do
      complex_options = {
        port: 8080,
        host: '0.0.0.0',
        ssl: {
          cert_file: '/path/to/cert.pem',
          key_file: '/path/to/key.pem'
        },
        middleware: ['cors', 'auth'],
        timeout: 30,
        max_connections: 1000
      }
      
      adapter = described_class.new(app, **complex_options)
      expect(adapter.options).to eq(complex_options)
    end
  end
end