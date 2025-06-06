# frozen_string_literal: true

require_relative '../lib/flashapi'

# Example FlashAPI application demonstrating modern Ruby features
module MyApp
  # Define routes using the new Routes DSL
  Routes = FlashAPI::Routes.draw do
    get '/', to: 'HomeResponder'
    get '/users', to: 'UsersResponder'
    post '/users', to: 'CreateUserResponder'
    get '/users/:id', to: 'UserResponder'
    put '/users/:id', to: 'UpdateUserResponder'
    delete '/users/:id', to: 'DeleteUserResponder'
  end

  # Home endpoint responder
  class HomeResponder < FlashAPI::BaseResponder
    def call
      render
    end

    private

    def render = ok(message: 'Welcome to FlashAPI!', version: FlashAPI::VERSION)
  end

  # List users endpoint
  class UsersResponder < FlashAPI::BaseResponder
    def call
      render
    end

    private

    def render
      # Simulated user data
      users = [
        { id: 1, name: 'Alice', email: 'alice@example.com' },
        { id: 2, name: 'Bob', email: 'bob@example.com' }
      ]

      ok(users:, count: users.size)
    end
  end

  # Create user endpoint
  class CreateUserResponder < FlashAPI::BaseResponder
    def call
      render
    end

    private

    def render
      # Validate input using pattern matching
      case params
      in { name: String => name, email: String => email }
        # Simulated user creation
        user = { id: 3, name:, email:, created_at: Time.now.iso8601 }
        created(user:)
      else
        unprocessable_entity(
          name: params[:name] ? nil : 'is required',
          email: params[:email] ? nil : 'is required'
        )
      end
    end
  end

  # Get single user endpoint
  class UserResponder < FlashAPI::BaseResponder
    def call
      render
    end

    private

    def render
      # Extract ID from path (in a real app, the router would handle this)
      user_id = request.uri.split('/').last.to_i
      
      # Simulated user lookup
      user = case user_id
             when 1 then { id: 1, name: 'Alice', email: 'alice@example.com' }
             when 2 then { id: 2, name: 'Bob', email: 'bob@example.com' }
             else nil
             end

      user ? ok(user:) : not_found("User with id #{user_id} not found")
    end
  end

  # Update user endpoint  
  class UpdateUserResponder < FlashAPI::BaseResponder
    def call
      render
    end

    private

    def render
      user_id = request.uri.split('/').last.to_i
      
      case [user_id, params]
      in [1..2, { name: String => name } | { email: String => email }]
        updated_user = { id: user_id, name:, email:, updated_at: Time.now.iso8601 }
        ok(user: updated_user)
      in [1..2, _]
        bad_request('Invalid update parameters')
      else
        not_found("User with id #{user_id} not found")
      end
    end
  end

  # Delete user endpoint
  class DeleteUserResponder < FlashAPI::BaseResponder
    def call
      render
    end

    private

    def render
      user_id = request.uri.split('/').last.to_i
      
      if (1..2).include?(user_id)
        no_content
      else
        not_found("User with id #{user_id} not found")
      end
    end
  end
end

# Start the server
if __FILE__ == $0
  puts "Starting FlashAPI example server..."
  puts "Available endpoints:"
  puts "  GET    /           - Home"
  puts "  GET    /users      - List users"
  puts "  POST   /users      - Create user"
  puts "  GET    /users/:id  - Get user"
  puts "  PUT    /users/:id  - Update user"
  puts "  DELETE /users/:id  - Delete user"
  puts ""
  
  # Use Rack adapter by default, or EventMachine if specified
  adapter = ARGV[0]&.to_sym || :rack
  port = (ARGV[1] || 3000).to_i
  
  begin
    FlashAPI.start(MyApp, adapter:, port:)
  rescue FlashAPI::AdapterNotFound => e
    puts "Error: #{e.message}"
    puts "Usage: ruby app.rb [adapter] [port]"
    puts "Example: ruby app.rb rack 3000"
    puts "Example: ruby app.rb eventmachine 3000"
  end
end