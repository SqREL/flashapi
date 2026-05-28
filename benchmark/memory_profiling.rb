# frozen_string_literal: true

require 'bundler/setup'
require 'memory_profiler'
require 'rack/test'

# Load frameworks
require 'flashapi'
require 'sinatra/base'
require 'grape'

# Define the same apps as in framework_comparison.rb
module FlashAPIBenchmark
  module Routes
    def self.paths
      @paths ||= {
        'GET /' => { method: 'get', responder: 'RootResponder', path: '/' },
        'GET /users' => { method: 'get', responder: 'UsersResponder', path: '/users' }
      }
    end
  end

  class RootResponder < FlashAPI::BaseResponder
    def call
      ok({ message: 'Hello, World!' })
    end
  end

  class UsersResponder < FlashAPI::BaseResponder
    def call
      users = Array.new(10) do |i|
        { id: i + 1, name: "User #{i + 1}", email: "user#{i + 1}@example.com" }
      end
      ok({ users: users })
    end
  end
end

class SinatraApp < Sinatra::Base
  set :logging, false
  
  get '/' do
    content_type :json
    { message: 'Hello, World!' }.to_json
  end
  
  get '/users' do
    content_type :json
    users = Array.new(10) do |i|
      { id: i + 1, name: "User #{i + 1}", email: "user#{i + 1}@example.com" }
    end
    { users: users }.to_json
  end
end

class GrapeApp < Grape::API
  format :json
  
  get '/' do
    { message: 'Hello, World!' }
  end
  
  get '/users' do
    users = Array.new(10) do |i|
      { id: i + 1, name: "User #{i + 1}", email: "user#{i + 1}@example.com" }
    end
    { users: users }
  end
end

# Memory profiling
class MemoryProfiler
  include Rack::Test::Methods
  
  attr_reader :app, :name
  
  def initialize(app, name)
    @app = app
    @name = name
  end
  
  def profile_request(path, requests: 100)
    puts "\n#{name} - Memory Profile for #{requests} requests to #{path}"
    puts "=" * 70
    
    report = ::MemoryProfiler.report do
      requests.times { get path }
    end
    
    puts "\nTotal allocated: #{report.total_allocated_memsize / 1024.0 / 1024.0} MB"
    puts "Total retained: #{report.total_retained_memsize / 1024.0} KB"
    puts "\nAllocated objects by type:"
    
    report.allocated_memory_by_class.sort_by { |_, size| -size }[0..9].each do |klass, size|
      puts "  #{klass}: #{'%.2f' % (size / 1024.0)} KB"
    end
    
    puts "\nAllocated objects by gem:"
    report.allocated_memory_by_gem.sort_by { |_, size| -size }[0..4].each do |gem, size|
      puts "  #{gem}: #{'%.2f' % (size / 1024.0)} KB"
    end
  end
end

# Run profiling
puts "Memory Profiling Report"
puts "======================"
puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"

# Profile each framework
[
  [FlashAPI.rack_app(FlashAPIBenchmark), 'FlashAPI'],
  [SinatraApp, 'Sinatra'],
  [GrapeApp, 'Grape']
].each do |app, name|
  profiler = MemoryProfiler.new(app, name)
  profiler.profile_request('/', requests: 100)
  profiler.profile_request('/users', requests: 100)
end

# Startup memory comparison
puts "\n\nStartup Memory Comparison"
puts "========================="

def measure_startup_memory(name, &block)
  report = ::MemoryProfiler.report(&block)
  
  puts "\n#{name}:"
  puts "  Total allocated: #{'%.2f' % (report.total_allocated_memsize / 1024.0 / 1024.0)} MB"
  puts "  Total retained: #{'%.2f' % (report.total_retained_memsize / 1024.0)} KB"
end

measure_startup_memory('FlashAPI') do
  FlashAPI.rack_app(FlashAPIBenchmark)
end

measure_startup_memory('Sinatra') do
  Class.new(Sinatra::Base) do
    get('/') { 'Hello' }
  end
end

measure_startup_memory('Grape') do
  Class.new(Grape::API) do
    get('/') { 'Hello' }
  end
end