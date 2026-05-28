# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark'
require 'rack/test'
require 'net/http'
require 'uri'

# Load frameworks
require 'flashapi'
require 'sinatra/base'
require 'grape'

# Test data
TEST_USERS = Array.new(100) do |i|
  {
    id: i + 1,
    username: "user_#{i + 1}",
    email: "user#{i + 1}@example.com",
    full_name: "Test User #{i + 1}",
    bio: "This is a bio for user #{i + 1}. " * 5,
    created_at: Time.now.to_s,
    updated_at: Time.now.to_s,
    posts_count: rand(100),
    followers_count: rand(1000),
    following_count: rand(500)
  }
end.freeze

# FlashAPI App
module ThroughputTest
  module Routes
    def self.paths
      @paths ||= {
        'GET /api/users' => { method: 'get', responder: 'UsersIndex', path: '/api/users' },
        'GET /api/users/:id' => { method: 'get', responder: 'UsersShow', path: '/api/users/:id' },
        'POST /api/users' => { method: 'post', responder: 'UsersCreate', path: '/api/users' },
        'PUT /api/users/:id' => { method: 'put', responder: 'UsersUpdate', path: '/api/users/:id' },
        'DELETE /api/users/:id' => { method: 'delete', responder: 'UsersDelete', path: '/api/users/:id' }
      }
    end
  end

  class UsersIndex < FlashAPI::BaseResponder
    def call
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 20).to_i
      offset = (page - 1) * per_page
      
      users = TEST_USERS[offset, per_page] || []
      
      ok({
        users: users,
        meta: {
          page: page,
          per_page: per_page,
          total: TEST_USERS.size,
          total_pages: (TEST_USERS.size.to_f / per_page).ceil
        }
      })
    end
  end

  class UsersShow < FlashAPI::BaseResponder
    def call
      id = params[:id].to_i
      user = TEST_USERS[id - 1]
      
      return not_found('User not found') unless user
      
      ok(user)
    end
  end

  class UsersCreate < FlashAPI::BaseResponder
    def call
      required = %i[username email full_name]
      missing = required - params.keys
      
      return unprocessable_entity(errors: { missing_fields: missing }) if missing.any?
      
      created({
        id: TEST_USERS.size + 1,
        username: params[:username],
        email: params[:email],
        full_name: params[:full_name],
        bio: params[:bio] || '',
        created_at: Time.now.to_s,
        updated_at: Time.now.to_s,
        posts_count: 0,
        followers_count: 0,
        following_count: 0
      })
    end
  end

  class UsersUpdate < FlashAPI::BaseResponder
    def call
      id = params[:id].to_i
      user = TEST_USERS[id - 1]
      
      return not_found('User not found') unless user
      
      updated_user = user.merge(
        params.slice(:username, :email, :full_name, :bio).merge(
          updated_at: Time.now.to_s
        )
      )
      
      ok(updated_user)
    end
  end

  class UsersDelete < FlashAPI::BaseResponder
    def call
      id = params[:id].to_i
      user = TEST_USERS[id - 1]
      
      return not_found('User not found') unless user
      
      no_content
    end
  end
end

# Sinatra App
class SinatraThroughputApp < Sinatra::Base
  set :logging, false
  set :show_exceptions, false
  
  helpers do
    def json_params
      @json_params ||= JSON.parse(request.body.read, symbolize_names: true) rescue {}
    end
  end
  
  get '/api/users' do
    content_type :json
    
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 20).to_i
    offset = (page - 1) * per_page
    
    users = TEST_USERS[offset, per_page] || []
    
    {
      users: users,
      meta: {
        page: page,
        per_page: per_page,
        total: TEST_USERS.size,
        total_pages: (TEST_USERS.size.to_f / per_page).ceil
      }
    }.to_json
  end
  
  get '/api/users/:id' do
    content_type :json
    
    id = params[:id].to_i
    user = TEST_USERS[id - 1]
    
    halt 404, { error: 'User not found' }.to_json unless user
    
    user.to_json
  end
  
  post '/api/users' do
    content_type :json
    
    data = json_params
    required = %i[username email full_name]
    missing = required - data.keys
    
    halt 422, { errors: { missing_fields: missing } }.to_json if missing.any?
    
    status 201
    {
      id: TEST_USERS.size + 1,
      username: data[:username],
      email: data[:email],
      full_name: data[:full_name],
      bio: data[:bio] || '',
      created_at: Time.now.to_s,
      updated_at: Time.now.to_s,
      posts_count: 0,
      followers_count: 0,
      following_count: 0
    }.to_json
  end
  
  put '/api/users/:id' do
    content_type :json
    
    id = params[:id].to_i
    user = TEST_USERS[id - 1]
    
    halt 404, { error: 'User not found' }.to_json unless user
    
    data = json_params
    updated_user = user.merge(
      data.slice(:username, :email, :full_name, :bio).merge(
        updated_at: Time.now.to_s
      )
    )
    
    updated_user.to_json
  end
  
  delete '/api/users/:id' do
    id = params[:id].to_i
    user = TEST_USERS[id - 1]
    
    halt 404, { error: 'User not found' }.to_json unless user
    
    status 204
    ''
  end
end

# Grape App
class GrapeThroughputApp < Grape::API
  format :json
  
  resource :users do
    get do
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 20).to_i
      offset = (page - 1) * per_page
      
      users = TEST_USERS[offset, per_page] || []
      
      {
        users: users,
        meta: {
          page: page,
          per_page: per_page,
          total: TEST_USERS.size,
          total_pages: (TEST_USERS.size.to_f / per_page).ceil
        }
      }
    end
    
    route_param :id do
      get do
        id = params[:id].to_i
        user = TEST_USERS[id - 1]
        
        error!('User not found', 404) unless user
        
        user
      end
      
      put do
        id = params[:id].to_i
        user = TEST_USERS[id - 1]
        
        error!('User not found', 404) unless user
        
        user.merge(
          params.slice(:username, :email, :full_name, :bio).merge(
            updated_at: Time.now.to_s
          )
        )
      end
      
      delete do
        id = params[:id].to_i
        user = TEST_USERS[id - 1]
        
        error!('User not found', 404) unless user
        
        status 204
        ''
      end
    end
    
    post do
      required = %i[username email full_name]
      missing = required - params.keys.map(&:to_sym)
      
      error!({ errors: { missing_fields: missing } }, 422) if missing.any?
      
      {
        id: TEST_USERS.size + 1,
        username: params[:username],
        email: params[:email],
        full_name: params[:full_name],
        bio: params[:bio] || '',
        created_at: Time.now.to_s,
        updated_at: Time.now.to_s,
        posts_count: 0,
        followers_count: 0,
        following_count: 0
      }
    end
  end
end

# Throughput tester
class ThroughputTester
  include Rack::Test::Methods
  
  attr_reader :app
  
  def initialize(app)
    @app = app
  end
  
  def run_test(name, requests: 10000)
    puts "\n#{name} Throughput Test (#{requests} requests)"
    puts "=" * 50
    
    scenarios = [
      { name: 'GET /api/users', weight: 40, action: -> { get '/api/users?page=1&per_page=20' } },
      { name: 'GET /api/users/:id', weight: 30, action: -> { get "/api/users/#{rand(1..100)}" } },
      { name: 'POST /api/users', weight: 15, action: -> {
        header 'Content-Type', 'application/json'
        post '/api/users', {
          username: "new_user_#{rand(1000)}",
          email: "new#{rand(1000)}@example.com",
          full_name: "New User #{rand(1000)}"
        }.to_json
      }},
      { name: 'PUT /api/users/:id', weight: 10, action: -> {
        header 'Content-Type', 'application/json'
        put "/api/users/#{rand(1..100)}", {
          bio: "Updated bio at #{Time.now}"
        }.to_json
      }},
      { name: 'DELETE /api/users/:id', weight: 5, action: -> { delete "/api/users/#{rand(1..100)}" } }
    ]
    
    # Build weighted request pool
    request_pool = []
    scenarios.each do |scenario|
      (scenario[:weight] * requests / 100).times { request_pool << scenario }
    end
    request_pool.shuffle!
    
    # Track metrics
    request_counts = Hash.new(0)
    status_counts = Hash.new(0)
    
    # Run benchmark
    start_time = Time.now
    
    request_pool.each do |scenario|
      scenario[:action].call
      request_counts[scenario[:name]] += 1
      status_counts[last_response.status] += 1
    end
    
    elapsed = Time.now - start_time
    rps = requests / elapsed
    
    # Report results
    puts "Total time: #{'%.2f' % elapsed} seconds"
    puts "Requests per second: #{'%.0f' % rps}"
    puts "\nRequest distribution:"
    request_counts.each do |endpoint, count|
      puts "  #{endpoint}: #{count}"
    end
    puts "\nStatus codes:"
    status_counts.each do |status, count|
      puts "  #{status}: #{count}"
    end
  end
end

# Run tests
puts "Framework Throughput Comparison"
puts "==============================="
puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"

[
  [FlashAPI.rack_app(ThroughputTest), 'FlashAPI'],
  [SinatraThroughputApp, 'Sinatra'],
  [Rack::Builder.new { run GrapeThroughputApp }.to_app, 'Grape']
].each do |app, name|
  tester = ThroughputTester.new(app)
  tester.run_test(name, requests: 5000)
end