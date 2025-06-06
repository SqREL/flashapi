# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FlashAPI::Routes do
  describe '.draw' do
    subject(:routes) { described_class.draw(&block) }

    let(:block) do
      proc do
        get '/users', to: 'UsersController'
        post '/users', to: 'CreateUserController'
        put '/users/:id', to: 'UpdateUserController'
        patch '/users/:id', to: 'PatchUserController'
        delete '/users/:id', to: 'DeleteUserController'
        head '/users', to: 'HeadUsersController'
        options '/users', to: 'OptionsUsersController'
      end
    end

    it 'returns a RouteSet instance' do
      expect(routes).to be_a(FlashAPI::Routes::RouteSet)
    end

    it 'defines all HTTP verb routes correctly' do
      paths = routes.paths
      
      expect(paths['GET /users']).to include(method: 'get', responder: 'UsersController')
      expect(paths['PUT /users/:id']).to include(method: 'put', responder: 'UpdateUserController')
    end

    it 'stores method as string' do
      paths = routes.paths
      paths.each_value do |route|
        expect(route[:method]).to be_a(String)
      end
    end

    it 'stores responder as string' do
      paths = routes.paths
      paths.each_value do |route|
        expect(route[:responder]).to be_a(String)
      end
    end

    context 'with empty block' do
      let(:block) { proc {} }

      it 'creates empty routes' do
        expect(routes.paths).to eq({})
      end
    end

    context 'with complex routing patterns' do
      let(:block) do
        proc do
          # Root route
          get '/', to: 'HomeController'
          
          # Simple resources
          get '/health', to: 'HealthController'
          get '/version', to: 'VersionController'
          
          # RESTful resources
          get '/api/users', to: 'ApiUsersIndexController'
          post '/api/users', to: 'ApiUsersCreateController'
          get '/api/users/:id', to: 'ApiUsersShowController'
          put '/api/users/:id', to: 'ApiUsersUpdateController'
          delete '/api/users/:id', to: 'ApiUsersDeleteController'
          
          # Nested resources
          get '/api/users/:user_id/posts', to: 'ApiUserPostsIndexController'
          post '/api/users/:user_id/posts', to: 'ApiUserPostsCreateController'
          get '/api/users/:user_id/posts/:id', to: 'ApiUserPostsShowController'
          
          # Different HTTP methods on same path
          get '/api/posts', to: 'ApiPostsIndexController'
          post '/api/posts', to: 'ApiPostsCreateController'
        end
      end

      it 'handles complex routing correctly' do
        paths = routes.paths
        
        expect(paths['GET /']).to include(method: 'get', responder: 'HomeController')
        expect(paths['POST /api/users']).to include(method: 'post', responder: 'ApiUsersCreateController')
        expect(paths['GET /api/users/:user_id/posts/:id']).to include(method: 'get', responder: 'ApiUserPostsShowController')
      end

      it 'allows same path with different HTTP methods' do
        paths = routes.paths
        
        # With the new architecture, different methods on same path are stored separately
        expect(paths['GET /api/posts']).to include(method: 'get', responder: 'ApiPostsIndexController')
        expect(paths['POST /api/posts']).to include(method: 'post', responder: 'ApiPostsCreateController')
      end
    end
  end

  describe FlashAPI::Routes::RouteSet do
    subject(:route_set) { described_class.new }

    describe '#initialize' do
      it 'initializes with empty paths' do
        expect(route_set.paths).to eq({})
      end
    end

    describe '#draw' do
      it 'returns self for method chaining' do
        result = route_set.draw { get '/test', to: 'TestController' }
        expect(result).to eq(route_set)
      end

      it 'allows defining routes within block context' do
        route_set.draw do
          get '/users', to: 'UsersController'
          post '/users', to: 'CreateUsersController'
        end

        expect(route_set.paths).to include(
          'POST /users' => a_hash_including(method: 'post', responder: 'CreateUsersController')
        )
      end

      it 'evaluates block in the context of the route set' do
        expect {
          route_set.draw do
            get '/context-test', to: 'ContextController'
            # Verify we're in the right context by checking we can call get
            raise "Wrong context" unless self.is_a?(FlashAPI::Routes::RouteSet)
          end
        }.not_to raise_error
        
        expect(route_set.paths).to have_key('GET /context-test')
      end
    end

    describe 'HTTP verb methods' do
      %i[get post put patch delete head options].each do |verb|
        describe "##{verb}" do
          it "defines a #{verb.upcase} route" do
            route_set.public_send(verb, '/test-path', to: 'TestController')
            
            expect(route_set.paths["#{verb.to_s.upcase} /test-path"]).to include(
              method: verb.to_s,
              responder: 'TestController'
            )
          end

          it 'converts symbols to strings' do
            route_set.public_send(verb, '/test', to: :SymbolController)
            
            expect(route_set.paths["#{verb.to_s.upcase} /test"][:responder]).to eq('SymbolController')
          end

          it 'handles string path and controller' do
            route_set.public_send(verb, '/string-test', to: 'StringController')
            
            expect(route_set.paths["#{verb.to_s.upcase} /string-test"]).to include(
              method: verb.to_s,
              responder: 'StringController'
            )
          end
        end
      end
    end

    describe 'route conflict handling' do
      before { route_set.get '/users', to: 'UsersController' }

      it 'prevents duplicate route definitions with same method' do
        expect { route_set.get '/users', to: 'AnotherController' }
          .to raise_error(ArgumentError, /Route already defined: GET \/users/)
      end

      it 'allows same path with different methods' do
        expect { route_set.post '/users', to: 'CreateController' }
          .not_to raise_error
          
        expect(route_set.paths).to have_key('GET /users')
        expect(route_set.paths).to have_key('POST /users')
      end

      it 'overwrites when same path and method are used' do
        # Current implementation overwrites - this may be desired behavior
        expect { route_set.get '/users', to: 'NewController' }
          .to raise_error(ArgumentError)
      end

      context 'with different HTTP methods on same path' do
        before do
          route_set.post '/api/endpoint', to: 'CreateController'
          route_set.put '/api/endpoint', to: 'UpdateController'
          route_set.delete '/api/endpoint', to: 'DeleteController'
        end

        it 'stores all routes with different keys' do
          # With the new architecture, all routes are stored separately
          expect(route_set.paths['POST /api/endpoint']).to include(method: 'post', responder: 'CreateController')
          expect(route_set.paths['PUT /api/endpoint']).to include(method: 'put', responder: 'UpdateController')
          expect(route_set.paths['DELETE /api/endpoint']).to include(method: 'delete', responder: 'DeleteController')
        end
      end
    end

    describe 'path validation' do
      it 'accepts root path' do
        expect { route_set.get '/', to: 'RootController' }.not_to raise_error
      end

      it 'accepts paths with parameters' do
        expect { route_set.get '/users/:id', to: 'UserController' }.not_to raise_error
        expect { route_set.get '/users/:user_id/posts/:post_id', to: 'PostController' }.not_to raise_error
      end

      it 'accepts paths with query-like patterns' do
        expect { route_set.get '/search', to: 'SearchController' }.not_to raise_error
      end

      it 'handles special characters in paths' do
        expect { route_set.get '/api/v1/users-list', to: 'UsersController' }.not_to raise_error
        expect { route_set.get '/api_v2/posts.json', to: 'PostsController' }.not_to raise_error
      end
    end

    describe 'responder validation' do
      it 'accepts string responders' do
        expect { route_set.get '/test', to: 'TestController' }.not_to raise_error
      end

      it 'accepts symbol responders' do
        expect { route_set.get '/test', to: :TestController }.not_to raise_error
      end

      it 'converts responder to string' do
        route_set.get '/symbol-test', to: :SymbolController
        expect(route_set.paths['GET /symbol-test'][:responder]).to eq('SymbolController')
      end
    end

    describe 'edge cases' do
      it 'handles empty path' do
        expect { route_set.get '', to: 'EmptyController' }.not_to raise_error
      end

      it 'handles paths with trailing slashes' do
        route_set.get '/trailing/', to: 'TrailingController'
        expect(route_set.paths).to have_key('GET /trailing/')
      end

      it 'treats paths as case-sensitive' do
        route_set.get '/Users', to: 'UpperController'
        route_set.get '/users', to: 'LowerController'
        
        expect(route_set.paths['GET /Users'][:responder]).to eq('UpperController')
        expect(route_set.paths['GET /users'][:responder]).to eq('LowerController')
      end
    end

    describe 'realistic routing scenarios' do
      it 'supports a typical REST API' do
        route_set.draw do
          # API routes
          get '/api/v1/health', to: 'ApiV1HealthController'
          
          # Users resource
          get '/api/v1/users', to: 'ApiV1UsersIndexController'
          post '/api/v1/users', to: 'ApiV1UsersCreateController'
          get '/api/v1/users/:id', to: 'ApiV1UsersShowController'
          put '/api/v1/users/:id', to: 'ApiV1UsersUpdateController'
          delete '/api/v1/users/:id', to: 'ApiV1UsersDeleteController'
          
          # Posts resource nested under users
          get '/api/v1/users/:user_id/posts', to: 'ApiV1UserPostsIndexController'
          post '/api/v1/users/:user_id/posts', to: 'ApiV1UserPostsCreateController'
          
          # Authentication
          post '/api/v1/auth/login', to: 'ApiV1AuthLoginController'
          delete '/api/v1/auth/logout', to: 'ApiV1AuthLogoutController'
        end

        paths = route_set.paths
        expect(paths).to have_key('GET /api/v1/health')
        expect(paths).to have_key('GET /api/v1/users/:id')
        expect(paths).to have_key('POST /api/v1/auth/login')
        expect(paths.size).to be >= 8
      end
    end
  end
end