# frozen_string_literal: true

require 'spec_helper'
require 'flashapi/streaming'

RSpec.describe FlashAPI::Streaming do
  describe FlashAPI::Streaming::StreamingResponse do
    let(:data) { %w[chunk1 chunk2 chunk3] }
    let(:enum) { data.each }
    let(:response) { described_class.new(enum) }

    describe '#each' do
      it 'yields each chunk from the enumerable' do
        chunks = []
        response.each { |chunk| chunks << chunk }
        expect(chunks).to eq(data)
      end

      it 'is enumerable' do
        expect(response).to be_a(Enumerable)
        expect(response.to_a).to eq(data)
      end
    end

    describe '#close' do
      context 'when enumerable responds to close' do
        let(:closeable_enum) do
          Class.new do
            include Enumerable
            
            def initialize
              @closed = false
            end
            
            def each
              yield 'chunk'
            end
            
            def close
              @closed = true
            end
            
            def closed?
              @closed
            end
          end.new
        end
        
        let(:response) { described_class.new(closeable_enum) }

        it 'calls close on the enumerable' do
          response.close
          expect(closeable_enum).to be_closed
        end
      end

      context 'when enumerable does not respond to close' do
        it 'does not raise an error' do
          expect { response.close }.not_to raise_error
        end
      end
    end
  end

  describe FlashAPI::Streaming::StreamingResponder do
    let(:responder_class) do
      Class.new(FlashAPI::BaseResponder) do
        include FlashAPI::Streaming::StreamingResponder
      end
    end

    let(:request) { FlashAPI::BaseRequest.new(uri: '/test', request_method: 'GET') }
    let(:responder) { responder_class.new(request) }

    describe '.stream_response' do
      it 'marks the responder class as streaming' do
        responder_class.stream_response
        expect(responder_class).to be_streaming
        expect(responder).to be_streaming
      end
    end

    describe '#stream' do
      it 'requires a block' do
        expect { responder.stream }.to raise_error(ArgumentError, 'Stream requires a block')
      end

      it 'creates a streaming response from block' do
        responder_class.stream_response  # Mark as streaming
        
        responder.stream do |yielder|
          yielder << 'chunk1'
          yielder << 'chunk2'
        end

        body = responder.body
        expect(body).to be_a(FlashAPI::Streaming::StreamingResponse)
        expect(body.to_a).to eq(%w[chunk1 chunk2])
      end
    end

    describe '#stream_json_array' do
      let(:data) { [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }] }

      before { responder_class.stream_response }

      it 'streams JSON array with proper formatting' do
        responder.stream_json_array(data)
        
        body = responder.body
        result = body.to_a.join
        
        expect(result).to start_with('[')
        expect(result).to end_with(']')
        expect(result).to include('{"id":1,"name":"Alice"}')
        expect(result).to include(',')
        expect(result).to include('{"id":2,"name":"Bob"}')
      end

      it 'handles empty arrays' do
        responder.stream_json_array([])
        
        body = responder.body
        result = body.to_a.join
        
        expect(result).to eq('[]')
      end
    end

    describe '#stream_ndjson' do
      let(:data) { [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }] }

      before { responder_class.stream_response }

      it 'streams NDJSON with newline delimiters' do
        responder.stream_ndjson(data)
        
        body = responder.body
        lines = body.to_a
        
        # Each line includes the JSON and the newline together
        expect(lines).to eq([
          "{\"id\":1,\"name\":\"Alice\"}\n",
          "{\"id\":2,\"name\":\"Bob\"}\n"
        ])
      end
    end

    describe '#body' do
      context 'when not streaming' do
        it 'uses the parent body method' do
          responder.instance_variable_set(:@render_result, { status_code: 200, body: { message: 'test' } })
          
          body = responder.body
          expect(body).to be_a(String)
          expect(Oj.load(body, symbol_keys: true)).to include(
            status_code: 200,
            success: true,
            message: 'test'
          )
        end
      end

      context 'when streaming' do
        before { responder_class.stream_response }

        it 'returns the streaming body' do
          responder.stream { |y| y << 'test' }
          
          body = responder.body
          expect(body).to be_a(FlashAPI::Streaming::StreamingResponse)
        end
      end
    end
  end

  describe 'Integration with Rack adapter' do
    let(:app_with_streaming) do
      Module.new.tap do |mod|
        mod.const_set(:Routes, FlashAPI::Routes.draw do
          get '/stream', to: 'StreamResponder'
          get '/stream_json', to: 'StreamJsonResponder'
          get '/normal', to: 'NormalResponder'
        end)

        # Streaming responder
        stream_responder = Class.new(FlashAPI::BaseResponder) do
          include FlashAPI::Streaming::StreamingResponder
          stream_response

          def call
            stream do |yielder|
              3.times { |i| yielder << "chunk#{i}\n" }
            end
          end
        end
        mod.const_set(:StreamResponder, stream_responder)

        # JSON streaming responder
        stream_json_responder = Class.new(FlashAPI::BaseResponder) do
          include FlashAPI::Streaming::StreamingResponder
          stream_response

          def call
            data = (1..3).map { |i| { id: i, value: "item#{i}" } }
            stream_json_array(data)
          end
        end
        mod.const_set(:StreamJsonResponder, stream_json_responder)

        # Normal responder
        normal_responder = Class.new(FlashAPI::BaseResponder) do
          def call
            @render_result = ok(message: 'Normal response')
          end
        end
        mod.const_set(:NormalResponder, normal_responder)
      end
    end

    let(:adapter) { FlashAPI::Adapters::Rack.new(app_with_streaming) }
    let(:app) { adapter }

    it 'handles streaming responses correctly' do
      env = Rack::MockRequest.env_for('/stream')
      status, _headers, body = app.call(env)

      expect(status).to eq(200)
      expect(body).to respond_to(:each)
      
      chunks = []
      body.each { |chunk| chunks << chunk }
      expect(chunks).to eq(["chunk0\n", "chunk1\n", "chunk2\n"])
    end

    it 'handles JSON streaming responses' do
      env = Rack::MockRequest.env_for('/stream_json')
      status, _headers, body = app.call(env)

      expect(status).to eq(200)
      expect(body).to respond_to(:each)
      
      result = body.to_a.join
      expect(result).to start_with('[')
      expect(result).to end_with(']')
      expect(result).to include('{"id":1,"value":"item1"}')
    end

    it 'handles normal responses as before' do
      env = Rack::MockRequest.env_for('/normal')
      status, _headers, body = app.call(env)

      expect(status).to eq(200)
      expect(body).to be_an(Array)
      expect(body.size).to eq(1)
      
      parsed = Oj.load(body[0], symbol_keys: true)
      expect(parsed).to include(
        status_code: 200,
        success: true,
        message: 'Normal response'
      )
    end
  end
end