# frozen_string_literal: true

require 'spec_helper'
require 'flashapi/object_pool'

RSpec.describe FlashAPI::ObjectPool do
  let(:factory) { -> { Object.new } }
  let(:pool) { described_class.new(size: 3, &factory) }

  describe '#initialize' do
    it 'requires a factory block' do
      expect { described_class.new(size: 10) }.to raise_error(ArgumentError, 'Factory block required')
    end

    it 'pre-populates the pool' do
      expect(factory).to receive(:call).exactly(3).times
      described_class.new(size: 3, &factory)
    end
  end

  describe '#borrow' do
    it 'returns an object from the pool' do
      obj = pool.borrow
      expect(obj).to be_an(Object)
    end

    it 'returns different objects on consecutive borrows' do
      obj1 = pool.borrow
      obj2 = pool.borrow
      expect(obj1).not_to equal(obj2)
    end

    context 'when pool is exhausted' do
      it 'blocks until an object is returned' do
        objects = []
        3.times { objects << pool.borrow }

        returned = false
        thread = Thread.new do
          sleep 0.01
          returned = true
          pool.return_object(objects.first)
        end

        # This should block until the thread returns an object
        obj = pool.borrow
        
        expect(returned).to be true
        expect(obj).to equal(objects.first)
        
        thread.join
      end
    end
  end

  describe '#return' do
    it 'returns an object to the pool' do
      obj = pool.borrow
      pool.return_object(obj)
      
      # Should get the same object back
      expect(pool.borrow).to equal(obj)
    end

    it 'does not exceed pool size' do
      extra_obj = Object.new
      3.times { pool.return_object(extra_obj) }
      
      # Pool should still only have 3 objects
      objects = []
      3.times { objects << pool.borrow }
      
      expect(objects.count(extra_obj)).to be <= 1
    end

    context 'with resettable objects' do
      let(:resettable_class) do
        Class.new do
          include FlashAPI::Poolable
          attr_accessor :value
          
          def initialize
            @value = nil
          end
        end
      end
      
      let(:pool) { described_class.new(size: 2) { resettable_class.new } }

      it 'resets objects before returning to pool' do
        obj = pool.borrow
        obj.value = 'test'
        
        pool.return_object(obj)
        
        obj2 = pool.borrow
        expect(obj2).to equal(obj)
        expect(obj2.value).to be_nil
      end
    end
  end

  describe '#with_object' do
    it 'borrows object, yields it, and returns automatically' do
      result = pool.with_object do |obj|
        expect(obj).to be_an(Object)
        'result'
      end
      
      expect(result).to eq('result')
    end

    it 'returns object even if block raises' do
      # Create a small pool to ensure we get the same object back
      small_pool = described_class.new(size: 1, &factory)
      
      obj_in_block = nil
      
      begin
        small_pool.with_object do |obj|
          obj_in_block = obj
          raise 'error'
        end
      rescue
        # Ignore error
      end
      
      # Object should be back in pool
      expect(small_pool.borrow).to equal(obj_in_block)
    end
  end
end

RSpec.describe FlashAPI::RackRequestPool do
  let(:pool) { described_class.new(size: 2) }

  describe '#with_request' do
    let(:env) { { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/test' } }

    it 'provides a pooled rack request wrapper' do
      pool.with_request(env) do |request|
        expect(request).to respond_to(:request_method)
        expect(request).to respond_to(:path_info)
        expect(request.request_method).to eq('GET')
        expect(request.path_info).to eq('/test')
      end
    end

    it 'resets request between uses' do
      env1 = { 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/test1' }
      env2 = { 'REQUEST_METHOD' => 'POST', 'PATH_INFO' => '/test2' }
      
      # Force pool to have only 1 object to ensure reuse
      small_pool = described_class.new(size: 1)
      
      request_ids = []
      
      small_pool.with_request(env1) do |r|
        request_ids << r.object_id
        expect(r.request_method).to eq('GET')
      end
      
      small_pool.with_request(env2) do |r|
        request_ids << r.object_id
        expect(r.request_method).to eq('POST')
      end
      
      # Should reuse the same wrapper object
      expect(request_ids[0]).to eq(request_ids[1])
    end
  end
end

RSpec.describe FlashAPI::BaseRequestPool do
  let(:pool) { described_class.new(size: 2) }

  describe '#build_request' do
    it 'builds a BaseRequest using pooled builder' do
      request = pool.build_request do |builder|
        builder
          .set(:protocol, 'http')
          .set(:request_method, 'GET')
          .set(:uri, '/test')
      end
      
      expect(request).to be_a(FlashAPI::BaseRequest)
      expect(request.protocol).to eq('http')
      expect(request.request_method).to eq('GET')
      expect(request.uri).to eq('/test')
    end

    it 'resets builder between uses' do
      # First request
      request1 = pool.build_request do |builder|
        builder.set(:uri, '/test1')
      end
      
      # Second request - should not have previous data
      request2 = pool.build_request do |builder|
        builder.set(:request_method, 'POST')
      end
      
      expect(request1.uri).to eq('/test1')
      expect(request1.request_method).to be_nil
      
      expect(request2.uri).to be_nil
      expect(request2.request_method).to eq('POST')
    end
  end
end