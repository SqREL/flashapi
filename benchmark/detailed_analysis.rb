# frozen_string_literal: true

require 'benchmark'
require 'rack'
require_relative '../lib/flashapi'

# FlashAPI application
module BenchmarkApp
  Routes = FlashAPI::Routes.draw do
    get '/hello', to: 'HelloResponder'
  end

  class HelloResponder < FlashAPI::BaseResponder
    def call
      @render_result = ok(message: 'Hello from FlashAPI!')
    end
  end
end

flashapi_app = FlashAPI::Adapters::Rack.new(BenchmarkApp)
flashapi_app_no_pool = FlashAPI::Adapters::Rack.new(BenchmarkApp, use_pooling: false)
env = Rack::MockRequest.env_for('/hello')

puts "Detailed Performance Analysis"
puts "============================="
puts

# Profile individual components
require 'ruby-prof' if defined?(RubyProf)

def profile_method(name)
  puts "\n#{name}:"
  puts "-" * name.length
  
  result = nil
  time = Benchmark.realtime { 1000.times { result = yield } }
  
  puts "Total time for 1000 calls: #{(time * 1000).round(2)}ms"
  puts "Average time per call: #{(time * 1000000 / 1000).round(2)}μs"
  result
end

# Test pool overhead
pool = FlashAPI::RackRequestPool.new(size: 10)
base_pool = FlashAPI::BaseRequestPool.new(size: 10)

profile_method("Pool borrow/return overhead") do
  pool.with_request(env) { |r| r }
end

profile_method("Base pool build overhead") do
  base_pool.build_request { |b| b.set(:uri, '/test').build }
end

# Test Mutex overhead
mutex = Mutex.new
counter = 0

profile_method("Mutex synchronization overhead") do
  mutex.synchronize { counter += 1 }
end

# Compare object creation
profile_method("Rack::Request.new") do
  ::Rack::Request.new(env)
end

profile_method("FlashAPI::BaseRequest.new") do
  FlashAPI::BaseRequest.new(
    protocol: 'http',
    request_method: 'GET',
    uri: '/hello',
    path_info: '/hello',
    query_string: '',
    headers: {}
  )
end

# Test full request cycle
profile_method("FlashAPI with pooling") do
  flashapi_app.call(env.dup)
end

profile_method("FlashAPI without pooling") do
  flashapi_app_no_pool.call(env.dup)
end

# Concurrent performance test
puts "\nConcurrent Request Test (100 threads, 100 requests each):"
puts "----------------------------------------------------------"

require 'thread'

def concurrent_test(name, app, env)
  start_time = Time.now
  errors = []
  
  threads = 100.times.map do
    Thread.new do
      100.times do
        begin
          status, _, _ = app.call(env.dup)
          errors << "Unexpected status: #{status}" unless status == 200
        rescue => e
          errors << "Error: #{e.message}"
        end
      end
    end
  end
  
  threads.each(&:join)
  elapsed = Time.now - start_time
  
  puts "\n#{name}:"
  puts "  Total time: #{(elapsed * 1000).round(2)}ms"
  puts "  Requests/sec: #{(10000 / elapsed).round(2)}"
  puts "  Errors: #{errors.length}"
  errors.first(5).each { |e| puts "    #{e}" } if errors.any?
end

concurrent_test("With pooling", flashapi_app, env)
concurrent_test("Without pooling", flashapi_app_no_pool, env)

# GC pressure test
puts "\nGC Pressure Test (10,000 requests):"
puts "------------------------------------"

def gc_test(name, app, env)
  GC.start
  gc_stats_before = GC.stat.dup
  
  start_time = Time.now
  10_000.times { app.call(env.dup) }
  elapsed = Time.now - start_time
  
  GC.start
  gc_stats_after = GC.stat
  
  puts "\n#{name}:"
  puts "  Time: #{(elapsed * 1000).round(2)}ms"
  puts "  GC runs: #{gc_stats_after[:count] - gc_stats_before[:count]}"
  puts "  Heap pages: #{gc_stats_after[:heap_available_slots] - gc_stats_before[:heap_available_slots]}"
  puts "  Major GC: #{gc_stats_after[:major_gc_count] - gc_stats_before[:major_gc_count]}"
  puts "  Minor GC: #{gc_stats_after[:minor_gc_count] - gc_stats_before[:minor_gc_count]}"
end

gc_test("With pooling", flashapi_app, env)
gc_test("Without pooling", flashapi_app_no_pool, env)