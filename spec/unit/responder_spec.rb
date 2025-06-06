# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FlashAPI::Responder do
  # Test class that includes the Responder module
  let(:responder_class) do
    Class.new do
      include FlashAPI::Responder

      def initialize(response_data = {})
        @response_data = response_data
      end

      private

      def render
        @response_data
      end
    end
  end

  subject(:responder) { responder_class.new(response_data) }

  describe '#status_code' do
    context 'with custom status code' do
      let(:response_data) { { status_code: 201 } }

      it 'returns the custom status code' do
        expect(responder.status_code).to eq(201)
      end
    end

    context 'without custom status code' do
      let(:response_data) { { body: { message: 'success' } } }

      it 'returns the default status code (200)' do
        expect(responder.status_code).to eq(200)
      end
    end

    context 'with nil response data' do
      let(:response_data) { {} }

      it 'returns the default status code' do
        expect(responder.status_code).to eq(200)
      end
    end
  end

  describe '#headers' do
    context 'with custom headers' do
      let(:response_data) { { headers: { 'X-Custom' => 'value', 'Cache-Control' => 'no-cache' } } }

      it 'returns the custom headers' do
        expect(responder.headers).to eq('X-Custom' => 'value', 'Cache-Control' => 'no-cache')
      end
    end

    context 'without custom headers' do
      let(:response_data) { { body: { data: 'test' } } }

      it 'returns the default headers' do
        expect(responder.headers).to eq('Content-Type' => 'application/json')
      end
    end

    context 'with nil headers' do
      let(:response_data) { { headers: nil } }

      it 'returns the default headers' do
        expect(responder.headers).to eq('Content-Type' => 'application/json')
      end
    end
  end

  describe '#body' do
    context 'with successful response' do
      let(:response_data) { { status_code: 200, body: { user: { id: 1, name: 'Alice' } } } }

      it 'returns JSON with status information and response body' do
        parsed_body = Oj.load(responder.body, symbol_keys: true)
        
        expect(parsed_body).to include(
          status_code: 200,
          success: true,
          user: { id: 1, name: 'Alice' }
        )
      end
    end

    context 'with error response' do
      let(:response_data) { { status_code: 400, body: { error: 'Bad request' } } }

      it 'marks response as unsuccessful' do
        parsed_body = Oj.load(responder.body, symbol_keys: true)
        
        expect(parsed_body).to include(
          status_code: 400,
          success: false,
          error: 'Bad request'
        )
      end
    end

    context 'with edge case status codes' do
      [
        [199, false],  # Below success range
        [200, true],   # Success boundary
        [299, true],   # Success boundary
        [300, false],  # Above success range
        [404, false],  # Client error
        [500, false]   # Server error
      ].each do |status, expected_success|
        context "with status code #{status}" do
          let(:response_data) { { status_code: status, body: { data: 'test' } } }

          it "sets success to #{expected_success}" do
            parsed_body = Oj.load(responder.body, symbol_keys: true)
            expect(parsed_body[:success]).to eq(expected_success)
          end
        end
      end
    end

    context 'with no body data' do
      let(:response_data) { { status_code: 204 } }

      it 'returns only status information' do
        parsed_body = Oj.load(responder.body, symbol_keys: true)
        
        expect(parsed_body).to eq(
          status_code: 204,
          success: true
        )
      end
    end

    context 'with nil body' do
      let(:response_data) { { status_code: 200, body: nil } }

      it 'handles nil body gracefully' do
        parsed_body = Oj.load(responder.body, symbol_keys: true)
        
        expect(parsed_body).to eq(
          status_code: 200,
          success: true
        )
      end
    end

    context 'with complex nested data' do
      let(:response_data) do
        {
          status_code: 201,
          body: {
            user: {
              id: 42,
              name: 'Bob',
              profile: {
                age: 30,
                interests: ['programming', 'music']
              }
            },
            metadata: {
              created_at: '2023-01-01T00:00:00Z',
              version: '1.0'
            }
          }
        }
      end

      it 'preserves complex data structures' do
        parsed_body = Oj.load(responder.body, symbol_keys: true)
        
        expect(parsed_body).to include(
          status_code: 201,
          success: true,
          user: {
            id: 42,
            name: 'Bob',
            profile: {
              age: 30,
              interests: ['programming', 'music']
            }
          },
          metadata: {
            created_at: '2023-01-01T00:00:00Z',
            version: '1.0'
          }
        )
      end
    end
  end

  describe '#render not implemented' do
    let(:responder_class) do
      Class.new do
        include FlashAPI::Responder
      end
    end
    
    let(:responder) { responder_class.new }

    it 'raises NotImplementedError with helpful message' do
      expect { responder.render }.to raise_error(
        NotImplementedError,
        /must implement #render method returning a hash/
      )
    end
  end

  describe 'constants' do
    it 'defines default status code' do
      expect(FlashAPI::Responder::DEFAULT_STATUS_CODE).to eq(200)
    end

    it 'defines default headers' do
      expect(FlashAPI::Responder::DEFAULT_HEADERS).to eq('Content-Type' => 'application/json')
    end

    it 'freezes default headers to prevent mutation' do
      expect(FlashAPI::Responder::DEFAULT_HEADERS).to be_frozen
    end
  end
end

RSpec.describe FlashAPI::BaseResponder do
  let(:request) do
    FlashAPI::BaseRequest.new(
      request_method: 'POST',
      uri: '/api/users',
      query_string: 'page=1&debug=true',
      content_type: 'application/json',
      post_content: '{"name":"Charlie","email":"charlie@example.com","role":"admin"}'
    )
  end

  subject(:responder) { described_class.new(request) }

  describe '#initialize' do
    it 'stores request' do
      expect(responder.request).to eq(request)
    end

    it 'extracts and merges parameters from query and JSON body' do
      expect(responder.params).to include(
        'page' => '1',
        'debug' => 'true',
        name: 'Charlie',
        email: 'charlie@example.com',
        role: 'admin'
      )
    end
  end

  describe '#call' do
    it 'raises NotImplementedError with helpful message' do
      expect { responder.call }.to raise_error(
        NotImplementedError,
        /must implement #call method/
      )
    end
  end

  describe 'parameter extraction' do
    context 'with GET request' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          request_method: 'GET',
          uri: '/api/search',
          query_string: 'q=ruby&limit=20&sort=relevance'
        )
      end

      it 'extracts only query parameters' do
        expect(responder.params).to eq(
          'q' => 'ruby',
          'limit' => '20',
          'sort' => 'relevance'
        )
      end
    end

    context 'with POST request containing both query and body' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          request_method: 'POST',
          uri: '/api/users',
          query_string: 'format=json&include_meta=true',
          content_type: 'application/json',
          post_content: '{"user":{"name":"Diana","email":"diana@test.com"},"notify":true}'
        )
      end

      it 'merges query parameters with JSON body' do
        expect(responder.params).to include(
          'format' => 'json',
          'include_meta' => 'true',
          user: { name: 'Diana', email: 'diana@test.com' },
          notify: true
        )
      end
    end

    context 'with PUT request' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          request_method: 'PUT',
          uri: '/api/users/123',
          query_string: 'validate=true',
          content_type: 'application/json',
          post_content: '{"name":"Updated Name"}'
        )
      end

      it 'includes both query and JSON body parameters' do
        expect(responder.params).to include(
          'validate' => 'true',
          name: 'Updated Name'
        )
      end
    end

    context 'with PATCH request' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          request_method: 'PATCH',
          uri: '/api/users/456',
          content_type: 'application/json',
          post_content: '{"email":"new@email.com"}'
        )
      end

      it 'extracts JSON body parameters' do
        expect(responder.params).to include(email: 'new@email.com')
      end
    end

    context 'with DELETE request' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          request_method: 'DELETE',
          uri: '/api/users/789',
          query_string: 'force=true&reason=test'
        )
      end

      it 'extracts only query parameters' do
        expect(responder.params).to eq(
          'force' => 'true',
          'reason' => 'test'
        )
      end
    end

    context 'with malformed JSON' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          request_method: 'POST',
          uri: '/api/test',
          query_string: 'fallback=true',
          content_type: 'application/json',
          post_content: '{"invalid": json}'
        )
      end

      it 'falls back to query parameters only' do
        expect(responder.params).to eq('fallback' => 'true')
      end
    end

    context 'with non-JSON content type' do
      let(:request) do
        FlashAPI::BaseRequest.new(
          request_method: 'POST',
          uri: '/api/upload',
          query_string: 'type=file',
          content_type: 'multipart/form-data',
          post_content: 'binary data here'
        )
      end

      it 'extracts only query parameters' do
        expect(responder.params).to eq('type' => 'file')
      end
    end
  end

  describe 'response helper methods' do
    describe '#ok' do
      it 'returns 200 status with optional body' do
        result = responder.send(:ok, message: 'Success', data: { id: 1 })
        expect(result).to eq(
          status_code: 200,
          body: { message: 'Success', data: { id: 1 } }
        )
      end

      it 'handles empty body' do
        result = responder.send(:ok)
        expect(result).to eq(status_code: 200, body: {})
      end
    end

    describe '#created' do
      it 'returns 201 status with optional body' do
        result = responder.send(:created, user: { id: 123, name: 'New User' })
        expect(result).to eq(
          status_code: 201,
          body: { user: { id: 123, name: 'New User' } }
        )
      end
    end

    describe '#no_content' do
      it 'returns 204 status with empty body' do
        result = responder.send(:no_content)
        expect(result).to eq(status_code: 204, body: {})
      end
    end

    describe '#bad_request' do
      it 'returns 400 status with error message' do
        result = responder.send(:bad_request, 'Invalid input data')
        expect(result).to eq(
          status_code: 400,
          body: { error: 'Invalid input data' }
        )
      end

      it 'uses default message when none provided' do
        result = responder.send(:bad_request)
        expect(result).to eq(
          status_code: 400,
          body: { error: 'Bad Request' }
        )
      end
    end

    describe '#unauthorized' do
      it 'returns 401 status with error message' do
        result = responder.send(:unauthorized, 'Token expired')
        expect(result).to eq(
          status_code: 401,
          body: { error: 'Token expired' }
        )
      end
    end

    describe '#forbidden' do
      it 'returns 403 status with error message' do
        result = responder.send(:forbidden, 'Access denied')
        expect(result).to eq(
          status_code: 403,
          body: { error: 'Access denied' }
        )
      end
    end

    describe '#not_found' do
      it 'returns 404 status with error message' do
        result = responder.send(:not_found, 'User not found')
        expect(result).to eq(
          status_code: 404,
          body: { error: 'User not found' }
        )
      end
    end

    describe '#unprocessable_entity' do
      it 'returns 422 status with validation errors' do
        errors = { name: 'is required', email: 'is invalid' }
        result = responder.send(:unprocessable_entity, errors)
        expect(result).to eq(
          status_code: 422,
          body: { errors: errors }
        )
      end

      it 'handles empty errors hash' do
        result = responder.send(:unprocessable_entity)
        expect(result).to eq(
          status_code: 422,
          body: { errors: {} }
        )
      end
    end

    describe '#internal_server_error' do
      it 'returns 500 status with error message' do
        result = responder.send(:internal_server_error, 'Database connection failed')
        expect(result).to eq(
          status_code: 500,
          body: { error: 'Database connection failed' }
        )
      end
    end
  end

  describe 'realistic responder implementation' do
    let(:user_responder_class) do
      Class.new(FlashAPI::BaseResponder) do
        def call
          case request.request_method.downcase
          when 'get'
            handle_get
          when 'post'
            handle_post
          when 'put'
            handle_put
          when 'delete'
            handle_delete
          else
            bad_request('Unsupported HTTP method')
          end
        end

        private

        def handle_get
          if params['id']
            ok(user: { id: params['id'], name: 'Test User' })
          else
            ok(users: [{ id: '1', name: 'User 1' }, { id: '2', name: 'User 2' }])
          end
        end

        def handle_post
          case params
          in { name: String => name, email: String => email } if name.length > 0 && email.include?('@')
            created(user: { id: '123', name: name, email: email })
          else
            unprocessable_entity(
              name: params[:name] ? nil : 'is required',
              email: params[:email]&.include?('@') ? nil : 'is invalid'
            )
          end
        end

        def handle_put
          if params['id'] && params[:name]
            ok(user: { id: params['id'], name: params[:name], updated: true })
          else
            bad_request('ID and name are required')
          end
        end

        def handle_delete
          if params['id']
            no_content
          else
            bad_request('User ID is required')
          end
        end
      end
    end

    describe 'GET requests' do
      context 'with user ID' do
        let(:request) do
          FlashAPI::BaseRequest.new(
            request_method: 'GET',
            uri: '/users/123',
            query_string: 'id=123'
          )
        end

        it 'returns specific user' do
          responder = user_responder_class.new(request)
          result = responder.call

          expect(result).to include(
            status_code: 200,
            body: { user: { id: '123', name: 'Test User' } }
          )
        end
      end

      context 'without user ID' do
        let(:request) do
          FlashAPI::BaseRequest.new(
            request_method: 'GET',
            uri: '/users'
          )
        end

        it 'returns all users' do
          responder = user_responder_class.new(request)
          result = responder.call

          expect(result).to include(
            status_code: 200,
            body: { users: [{ id: '1', name: 'User 1' }, { id: '2', name: 'User 2' }] }
          )
        end
      end
    end

    describe 'POST requests' do
      context 'with valid data' do
        let(:request) do
          FlashAPI::BaseRequest.new(
            request_method: 'POST',
            uri: '/users',
            content_type: 'application/json',
            post_content: '{"name":"Alice","email":"alice@example.com"}'
          )
        end

        it 'creates user successfully' do
          responder = user_responder_class.new(request)
          result = responder.call

          expect(result).to include(
            status_code: 201,
            body: { user: { id: '123', name: 'Alice', email: 'alice@example.com' } }
          )
        end
      end

      context 'with invalid data' do
        let(:request) do
          FlashAPI::BaseRequest.new(
            request_method: 'POST',
            uri: '/users',
            content_type: 'application/json',
            post_content: '{"name":"","email":"invalid-email"}'
          )
        end

        it 'returns validation errors' do
          responder = user_responder_class.new(request)
          result = responder.call

          expect(result).to include(
            status_code: 422,
            body: { errors: a_hash_including(email: 'is invalid') }
          )
        end
      end
    end
  end
end