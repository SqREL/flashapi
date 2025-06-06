# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FlashAPI::BaseRequest do
  subject(:request) { described_class.new(**params) }

  let(:params) do
    {
      protocol: 'https',
      request_method: 'POST',
      uri: '/api/users',
      query_string: 'page=1&limit=10&sort=name',
      content_type: 'application/json; charset=utf-8',
      post_content: '{"name":"Alice","email":"alice@example.com"}',
      headers: { 'Authorization' => 'Bearer token123', 'User-Agent' => 'TestAgent/1.0' },
      cookie: { 'session_id' => 'abc123' },
      path_info: '/api/users'
    }
  end

  describe 'Data class behavior' do
    it 'is immutable' do
      expect { request.protocol = 'http' }.to raise_error(NoMethodError)
    end

    it 'provides all attribute readers' do
      expect(request).to have_attributes(
        protocol: 'https',
        request_method: 'POST',
        uri: '/api/users',
        query_string: 'page=1&limit=10&sort=name',
        content_type: 'application/json; charset=utf-8'
      )
    end

    it 'supports pattern matching' do
      case request
      in { protocol: 'https', request_method: 'POST', uri: '/api/users' }
        expect(true).to be true
      else
        fail 'Pattern matching failed'
      end
    end

    it 'can be created with keyword arguments' do
      req = described_class.new(protocol: 'http', request_method: 'GET')
      expect(req.protocol).to eq('http')
      expect(req.request_method).to eq('GET')
    end

    it 'handles nil values gracefully' do
      req = described_class.new
      expect(req.protocol).to be_nil
      expect(req.headers).to eq({})
    end
  end

  describe 'HTTP method helpers' do
    [
      ['GET', :get?, true],
      ['POST', :post?, true],
      ['PUT', :put?, true],
      ['DELETE', :delete?, true],
      ['PATCH', :patch?, true],
      ['HEAD', :get?, false],
      ['OPTIONS', :get?, false],
      [nil, :get?, false]
    ].each do |method, helper, expected|
      context "with #{method || 'nil'} request" do
        let(:params) { super().merge(request_method: method) }

        it "#{expected ? 'returns true' : 'returns false'} for #{helper}" do
          expect(request.public_send(helper)).to eq(expected)
        end
      end
    end

    it 'is case insensitive' do
      get_request = described_class.new(request_method: 'get')
      post_request = described_class.new(request_method: 'Post')
      
      expect(get_request).to be_get
      expect(post_request).to be_post
    end
  end

  describe '#json?' do
    [
      ['application/json', true],
      ['application/json; charset=utf-8', true],
      ['APPLICATION/JSON', true],
      ['text/html', false],
      ['text/plain', false],
      ['application/xml', false],
      [nil, false],
      ['', false]
    ].each do |content_type, expected|
      context "with content type '#{content_type}'" do
        let(:params) { super().merge(content_type: content_type) }

        it "returns #{expected}" do
          expect(request.json?).to eq(expected)
        end
      end
    end
  end

  describe '#header' do
    it 'retrieves headers case-insensitively' do
      expect(request.header('authorization')).to eq('Bearer token123')
      expect(request.header('AUTHORIZATION')).to eq('Bearer token123')
      expect(request.header(:authorization)).to eq('Bearer token123')
      expect(request.header('User-Agent')).to eq('TestAgent/1.0')
    end

    it 'returns nil for missing headers' do
      expect(request.header('X-Missing')).to be_nil
      expect(request.header('')).to be_nil
    end

    it 'handles nil headers gracefully' do
      req = described_class.new(headers: nil)
      expect(req.header('any')).to be_nil
    end

    it 'handles non-hash headers' do
      req = described_class.new(headers: 'not-a-hash')
      expect(req.header('any')).to be_nil
    end
  end

  describe '#query_params' do
    it 'parses standard query string' do
      expect(request.query_params).to eq(
        'page' => '1',
        'limit' => '10', 
        'sort' => 'name'
      )
    end

    context 'with empty query string' do
      let(:params) { super().merge(query_string: '') }

      it 'returns empty hash' do
        expect(request.query_params).to eq({})
      end
    end

    context 'with nil query string' do
      let(:params) { super().merge(query_string: nil) }

      it 'returns empty hash' do
        expect(request.query_params).to eq({})
      end
    end

    context 'with complex query string' do
      let(:params) { super().merge(query_string: 'filter[name]=john&filter[age]=25&tags[]=red&tags[]=blue') }

      it 'parses arrays and nested params' do
        result = request.query_params
        expect(result['filter[name]']).to eq('john')
        expect(result['filter[age]']).to eq('25')
        expect(result['tags[]']).to eq('red') # CGI.parse takes first value
      end
    end

    context 'with URL encoded values' do
      let(:params) { super().merge(query_string: 'message=hello%20world&special=%21%40%23') }

      it 'decodes URL encoded values' do
        result = request.query_params
        expect(result['message']).to eq('hello world')
        expect(result['special']).to eq('!@#')
      end
    end

    context 'with malformed query string' do
      let(:params) { super().merge(query_string: '%%%invalid%%%') }

      it 'handles malformed query strings gracefully' do
        # CGI.parse is quite tolerant, so it still parses some malformed strings
        # The important thing is that it doesn't crash
        expect { request.query_params }.not_to raise_error
        expect(request.query_params).to be_a(Hash)
      end
    end
  end

  describe '#json_body' do
    context 'with valid JSON content' do
      it 'parses JSON with symbol keys' do
        expect(request.json_body).to eq(
          name: 'Alice',
          email: 'alice@example.com'
        )
      end
    end

    context 'with complex JSON' do
      let(:params) do
        super().merge(
          post_content: '{"user":{"name":"Bob","profile":{"age":30,"tags":["admin","user"]}},"timestamp":"2023-01-01T00:00:00Z"}'
        )
      end

      it 'parses nested JSON structures' do
        result = request.json_body
        expect(result).to include(
          user: {
            name: 'Bob',
            profile: {
              age: 30,
              tags: ['admin', 'user']
            }
          },
          timestamp: '2023-01-01T00:00:00Z'
        )
      end
    end

    context 'with invalid JSON' do
      let(:params) { super().merge(post_content: '{"invalid": json}') }

      it 'returns empty hash' do
        expect(request.json_body).to eq({})
      end
    end

    context 'with non-JSON content type' do
      let(:params) { super().merge(content_type: 'text/plain') }

      it 'returns empty hash' do
        expect(request.json_body).to eq({})
      end
    end

    context 'with nil post content' do
      let(:params) { super().merge(post_content: nil) }

      it 'returns empty hash' do
        expect(request.json_body).to eq({})
      end
    end

    context 'with empty post content' do
      let(:params) { super().merge(post_content: '') }

      it 'returns empty hash' do
        expect(request.json_body).to eq({})
      end
    end
  end

  describe 'realistic usage scenarios' do
    context 'typical GET request' do
      let(:get_request) do
        described_class.new(
          protocol: 'https',
          request_method: 'GET',
          uri: '/api/users',
          query_string: 'page=2&per_page=50&search=john',
          headers: {
            'Accept' => 'application/json',
            'User-Agent' => 'MyApp/1.0',
            'Authorization' => 'Bearer xyz789'
          }
        )
      end

      it 'provides expected functionality' do
        expect(get_request).to be_get
        expect(get_request).not_to be_json
        expect(get_request.query_params).to include('page' => '2', 'per_page' => '50')
        expect(get_request.header('authorization')).to eq('Bearer xyz789')
        expect(get_request.json_body).to eq({})
      end
    end

    context 'typical POST request' do
      let(:post_request) do
        described_class.new(
          protocol: 'https',
          request_method: 'POST',
          uri: '/api/users',
          content_type: 'application/json',
          post_content: '{"name":"Charlie","email":"charlie@test.com","role":"admin"}',
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer abc456'
          }
        )
      end

      it 'provides expected functionality' do
        expect(post_request).to be_post
        expect(post_request).to be_json
        expect(post_request.json_body).to include(
          name: 'Charlie',
          email: 'charlie@test.com',
          role: 'admin'
        )
        expect(post_request.query_params).to eq({})
      end
    end
  end
end