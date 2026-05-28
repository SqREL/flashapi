# frozen_string_literal: true

require 'benchmark/ips'
require 'rack'
require 'json'
require_relative '../lib/flashapi'

# Raw Rack application for comparison
class RawRackApp
  def call(env)
    case [env['REQUEST_METHOD'], env['PATH_INFO']]
    when ['GET', '/hello']
      [200, { 'Content-Type' => 'application/json' }, ['{"message":"Hello from raw Rack!"}']]
    when ['POST', '/echo']
      body = env['rack.input'].read
      [200, { 'Content-Type' => 'application/json' }, [body]]
    else
      [404, { 'Content-Type' => 'application/json' }, ['{"error":"Not found"}']]
    end
  end
end

# FlashAPI application
module BenchmarkApp
  Routes = FlashAPI::Routes.draw do
    get '/hello', to: 'HelloResponder'
    post '/echo', to: 'EchoResponder'
  end

  class HelloResponder < FlashAPI::BaseResponder
    def call
      @render_result = ok(message: 'Hello from FlashAPI!')
    end
  end

  class EchoResponder < FlashAPI::BaseResponder
    def call
      @render_result = ok(params)
    end
  end
end

# Benchmark setup
raw_rack_app = RawRackApp.new
flashapi_app = FlashAPI::Adapters::Rack.new(BenchmarkApp)
flashapi_app_no_pool = FlashAPI::Adapters::Rack.new(BenchmarkApp, use_pooling: false)

# Test environments
get_env = Rack::MockRequest.env_for('/hello')
post_env = Rack::MockRequest.env_for('/echo', 
  method: 'POST',
  input: '{"message":"test"}',
  'CONTENT_TYPE' => 'application/json'
)
not_found_env = Rack::MockRequest.env_for('/nonexistent')

puts "FlashAPI Rack Adapter Performance Benchmark"
puts "==========================================="
puts

# Warm up
100.times do
  raw_rack_app.call(get_env.dup)
  flashapi_app.call(get_env.dup)
  flashapi_app_no_pool.call(get_env.dup)
end

# GET request benchmark
puts "GET /hello Request Benchmark:"
puts "-----------------------------"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Raw Rack") do
    raw_rack_app.call(get_env.dup)
  end

  x.report("FlashAPI (with pooling)") do
    flashapi_app.call(get_env.dup)
  end

  x.report("FlashAPI (no pooling)") do
    flashapi_app_no_pool.call(get_env.dup)
  end

  x.compare!
end

puts "\nPOST /echo Request Benchmark:"
puts "-----------------------------"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Raw Rack") do
    env = post_env.dup
    env['rack.input'] = StringIO.new('{"message":"test"}')
    raw_rack_app.call(env)
  end

  x.report("FlashAPI (with pooling)") do
    env = post_env.dup
    env['rack.input'] = StringIO.new('{"message":"test"}')
    flashapi_app.call(env)
  end

  x.report("FlashAPI (no pooling)") do
    env = post_env.dup
    env['rack.input'] = StringIO.new('{"message":"test"}')
    flashapi_app_no_pool.call(env)
  end

  x.compare!
end

puts "\n404 Not Found Benchmark:"
puts "------------------------"
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Raw Rack") do
    raw_rack_app.call(not_found_env.dup)
  end

  x.report("FlashAPI (with pooling)") do
    flashapi_app.call(not_found_env.dup)
  end

  x.report("FlashAPI (no pooling)") do
    flashapi_app_no_pool.call(not_found_env.dup)
  end

  x.compare!
end

# Memory allocation benchmark
puts "\nMemory Allocation Benchmark (per request):"
puts "------------------------------------------"

require 'objspace'

def measure_allocations
  GC.start
  GC.disable
  before = ObjectSpace.count_objects
  yield
  after = ObjectSpace.count_objects
  GC.enable
  
  allocations = {}
  after.each do |type, count|
    diff = count - before[type]
    allocations[type] = diff if diff > 0
  end
  allocations
end

# Measure allocations for each implementation
puts "\nRaw Rack allocations:"
allocations = measure_allocations { 100.times { raw_rack_app.call(get_env.dup) } }
allocations.each { |type, count| puts "  #{type}: #{count / 100.0}" }

puts "\nFlashAPI (with pooling) allocations:"
allocations = measure_allocations { 100.times { flashapi_app.call(get_env.dup) } }
allocations.each { |type, count| puts "  #{type}: #{count / 100.0}" }

puts "\nFlashAPI (no pooling) allocations:"
allocations = measure_allocations { 100.times { flashapi_app_no_pool.call(get_env.dup) } }
allocations.each { |type, count| puts "  #{type}: #{count / 100.0}" }