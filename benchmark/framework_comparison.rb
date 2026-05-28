# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark/ips'
require 'rack'
require 'rack/test'
require 'json'

# Load frameworks
require 'flashapi'
require 'sinatra/base'
require 'grape'

# Sample data for responses
SIMPLE_RESPONSE = { message: 'Hello, World!', timestamp: Time.now.to_i }.freeze
COMPLEX_RESPONSE = {
  users: Array.new(10) do |i|
    {
      id: i + 1,
      name: "User #{i + 1}",
      email: "user#{i + 1}@example.com",
      profile: {
        age: 20 + i,
        location: "City #{i + 1}",
        interests: %w[coding reading traveling]
      }
    }
  end,
  meta: {
    total: 10,
    page: 1,
    per_page: 10
  }
}.freeze

# FlashAPI Application
module FlashAPIBenchmark
  module Routes
    def self.paths
      @paths ||= {
        'GET /' => { method: 'get', responder: 'RootResponder', path: '/' },
        'GET /users' => { method: 'get', responder: 'UsersResponder', path: '/users' },
        'POST /users' => { method: 'post', responder: 'CreateUserResponder', path: '/users' },
        'GET /health' => { method: 'get', responder: 'HealthResponder', path: '/health' }
      }
    end
  end

  class RootResponder < FlashAPI::BaseResponder
    def call
      ok(SIMPLE_RESPONSE)
    end
  end

  class UsersResponder < FlashAPI::BaseResponder
    def call
      ok(COMPLEX_RESPONSE)
    end
  end

  class CreateUserResponder < FlashAPI::BaseResponder
    def call
      created({ id: 11, name: params[:name], email: params[:email] })
    end
  end

  class HealthResponder < FlashAPI::BaseResponder
    def call
      ok({ status: 'healthy', timestamp: Time.now.to_i })
    end
  end
end

# Sinatra Application
class SinatraApp < Sinatra::Base
  set :logging, false
  set :dump_errors, false
  set :show_exceptions, false

  get '/' do
    content_type :json
    SIMPLE_RESPONSE.to_json
  end

  get '/users' do
    content_type :json
    COMPLEX_RESPONSE.to_json
  end

  post '/users' do
    content_type :json
    data = JSON.parse(request.body.read)
    { id: 11, name: data['name'], email: data['email'] }.to_json
  end

  get '/health' do
    content_type :json
    { status: 'healthy', timestamp: Time.now.to_i }.to_json
  end
end

# Grape Application
class GrapeApp < Grape::API
  format :json

  get '/' do
    SIMPLE_RESPONSE
  end

  get '/users' do
    COMPLEX_RESPONSE
  end

  post '/users' do
    { id: 11, name: params[:name], email: params[:email] }
  end

  get '/health' do
    { status: 'healthy', timestamp: Time.now.to_i }
  end
end

# Create Rack apps
flashapi_app = FlashAPI.rack_app(FlashAPIBenchmark)
sinatra_app = SinatraApp
grape_app = GrapeApp

# Benchmark runner
class BenchmarkRunner
  include Rack::Test::Methods
  
  attr_reader :app
  
  def initialize(app)
    @app = app
  end
  
  def get_root
    get '/'
  end
  
  def get_users
    get '/users'
  end
  
  def post_user
    header 'Content-Type', 'application/json'
    post '/users', { name: 'John Doe', email: 'john@example.com' }.to_json
  end
  
  def get_health
    get '/health'
  end
end

puts "Framework Performance Comparison"
puts "================================"
puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts

# Simple GET request benchmark
puts "Simple GET / request:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)
  
  flashapi_runner = BenchmarkRunner.new(flashapi_app)
  sinatra_runner = BenchmarkRunner.new(sinatra_app)
  grape_runner = BenchmarkRunner.new(grape_app)
  
  x.report("FlashAPI") { flashapi_runner.get_root }
  x.report("Sinatra") { sinatra_runner.get_root }
  x.report("Grape") { grape_runner.get_root }
  
  x.compare!
end

# Complex GET request benchmark
puts "\nComplex GET /users request:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)
  
  flashapi_runner = BenchmarkRunner.new(flashapi_app)
  sinatra_runner = BenchmarkRunner.new(sinatra_app)
  grape_runner = BenchmarkRunner.new(grape_app)
  
  x.report("FlashAPI") { flashapi_runner.get_users }
  x.report("Sinatra") { sinatra_runner.get_users }
  x.report("Grape") { grape_runner.get_users }
  
  x.compare!
end

# POST request benchmark
puts "\nPOST /users request:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)
  
  flashapi_runner = BenchmarkRunner.new(flashapi_app)
  sinatra_runner = BenchmarkRunner.new(sinatra_app)
  grape_runner = BenchmarkRunner.new(grape_app)
  
  x.report("FlashAPI") { flashapi_runner.post_user }
  x.report("Sinatra") { sinatra_runner.post_user }
  x.report("Grape") { grape_runner.post_user }
  
  x.compare!
end

# Routing performance (404 response)
puts "\n404 Not Found response:"
puts "-" * 50

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)
  
  flashapi_runner = BenchmarkRunner.new(flashapi_app)
  sinatra_runner = BenchmarkRunner.new(sinatra_app)
  grape_runner = BenchmarkRunner.new(grape_app)
  
  x.report("FlashAPI") { flashapi_runner.get '/nonexistent' }
  x.report("Sinatra") { sinatra_runner.get '/nonexistent' }
  x.report("Grape") { grape_runner.get '/nonexistent' }
  
  x.compare!
end

# Memory usage comparison
puts "\nMemory Usage Analysis:"
puts "=" * 50

require 'objspace'

def measure_memory(&block)
  GC.start
  GC.disable
  before = ObjectSpace.memsize_of_all
  
  block.call
  
  after = ObjectSpace.memsize_of_all
  GC.enable
  
  (after - before) / 1024.0 / 1024.0 # Convert to MB
end

puts "\nMemory used for 1000 requests to GET /users:"
puts "-" * 50

%w[FlashAPI Sinatra Grape].each do |framework|
  app = case framework
        when 'FlashAPI' then flashapi_app
        when 'Sinatra' then sinatra_app
        when 'Grape' then grape_app
        end
  
  runner = BenchmarkRunner.new(app)
  
  memory = measure_memory do
    1000.times { runner.get_users }
  end
  
  puts "#{framework}: #{'%.2f' % memory} MB"
end