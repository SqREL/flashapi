# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FlashAPI::Application do
  let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/users', request_method: 'GET') }
  
  describe '.run' do
    subject(:run_app) { described_class.run(request, app_module) }

    context 'with valid application module' do
      let(:app_module) do
        Module.new.tap do |mod|
          routes = FlashAPI::Routes.draw do
            get '/users', to: 'UsersController'
            post '/users', to: 'CreateUserController'
            put '/users/:id', to: 'UpdateUserController'
            delete '/users/:id', to: 'DeleteUserController'
          end
          mod.const_set(:Routes, routes)

          mod.const_set(:UsersController, Class.new)
          mod.const_set(:CreateUserController, Class.new)
          mod.const_set(:UpdateUserController, Class.new)
          mod.const_set(:DeleteUserController, Class.new)
        end
      end

      it 'returns the correct responder class for exact route match' do
        expect(run_app).to eq(app_module::UsersController)
      end

      context 'with different HTTP methods' do
        let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/users', request_method: 'POST') }

        it 'returns the correct responder for POST' do
          expect(run_app).to eq(app_module::CreateUserController)
        end
      end

      context 'with parameterized routes' do
        let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/users/:id', request_method: 'PUT') }

        it 'matches parameterized routes' do
          expect(run_app).to eq(app_module::UpdateUserController)
        end
      end

      context 'with case-insensitive HTTP methods' do
        let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/users', request_method: 'get') }

        it 'handles lowercase method names' do
          expect(run_app).to eq(app_module::UsersController)
        end
      end

      context 'with method symbols' do
        let(:app_module) do
          Module.new.tap do |mod|
            routes = instance_double(FlashAPI::Routes::RouteSet, paths: { 'GET /test' => { method: :get, responder: 'TestController', path: '/test' } })
            mod.const_set(:Routes, routes)
            mod.const_set(:TestController, Class.new)
          end
        end
        let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/test', request_method: 'GET') }

        it 'handles symbol method types' do
          expect(run_app).to eq(app_module::TestController)
        end
      end
    end

    context 'with route not found' do
      let(:app_module) do
        Module.new.tap do |mod|
          routes = FlashAPI::Routes.draw do
            get '/users', to: 'UsersController'
          end
          mod.const_set(:Routes, routes)
          mod.const_set(:UsersController, Class.new)
        end
      end

      let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/nonexistent', request_method: 'GET') }

      it 'raises NoRouteMatch with descriptive message' do
        expect { run_app }.to raise_error(
          FlashAPI::NoRouteMatch,
          'No route found for: /nonexistent'
        )
      end
    end

    context 'with wrong HTTP method' do
      let(:app_module) do
        Module.new.tap do |mod|
          routes = FlashAPI::Routes.draw do
            get '/users', to: 'UsersController'
          end
          mod.const_set(:Routes, routes)
          mod.const_set(:UsersController, Class.new)
        end
      end

      let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/users', request_method: 'DELETE') }

      it 'raises NoRouteMatch with method not allowed message' do
        expect { run_app }.to raise_error(
          FlashAPI::NoRouteMatch,
          /Method not allowed: DELETE for \/users\. Available methods: GET/
        )
      end
    end

    context 'with invalid scope module' do
      let(:app_module) { Module.new }  # No Routes constant

      it 'raises ArgumentError with helpful message' do
        expect { run_app }.to raise_error(
          ArgumentError,
          /Invalid scope: .* must define Routes\.paths/
        )
      end
    end

    context 'with missing Routes.paths method' do
      let(:app_module) do
        Module.new.tap do |mod|
          mod.const_set(:Routes, Class.new)  # Routes exists but no paths method
        end
      end

      it 'raises ArgumentError' do
        expect { run_app }.to raise_error(ArgumentError)
      end
    end

    context 'with missing responder class' do
      let(:app_module) do
        Module.new.tap do |mod|
          routes = FlashAPI::Routes.draw do
            get '/test', to: 'MissingController'
          end
          mod.const_set(:Routes, routes)
          # Note: MissingController is not defined
        end
      end

      let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/test', request_method: 'GET') }

      it 'raises NameError with helpful message' do
        expect { run_app }.to raise_error(
          NameError,
          /Responder not found: .*::MissingController/
        )
      end
    end

    context 'with complex routing scenarios' do
      let(:app_module) do
        Module.new.tap do |mod|
          routes = FlashAPI::Routes.draw do
            get '/', to: 'HomeController'
            get '/health', to: 'HealthController'
            
            # User resources
            get '/users', to: 'UsersIndexController'
            post '/users', to: 'UsersCreateController'
            get '/users/:id', to: 'UsersShowController'
            put '/users/:id', to: 'UsersUpdateController'
            patch '/users/:id', to: 'UsersPatchController'
            delete '/users/:id', to: 'UsersDeleteController'
            
            # Nested resources
            get '/users/:user_id/posts', to: 'UserPostsController'
            post '/users/:user_id/posts', to: 'CreateUserPostController'
          end
          mod.const_set(:Routes, routes)

          # Define all controller classes
          %w[
            HomeController HealthController
            UsersIndexController UsersCreateController UsersShowController 
            UsersUpdateController UsersPatchController UsersDeleteController
            UserPostsController CreateUserPostController
          ].each do |controller_name|
            mod.const_set(controller_name, Class.new)
          end
        end
      end

      [
        ['GET', '/', 'HomeController'],
        ['GET', '/health', 'HealthController'],
        ['GET', '/users', 'UsersIndexController'],
        ['POST', '/users', 'UsersCreateController'],
        ['GET', '/users/:id', 'UsersShowController'],
        ['PUT', '/users/:id', 'UsersUpdateController'],
        ['PATCH', '/users/:id', 'UsersPatchController'],
        ['DELETE', '/users/:id', 'UsersDeleteController'],
        ['GET', '/users/:user_id/posts', 'UserPostsController'],
        ['POST', '/users/:user_id/posts', 'CreateUserPostController']
      ].each do |method, path, expected_controller|
        context "#{method} #{path}" do
          let(:request) { instance_double(FlashAPI::BaseRequest, uri: path, request_method: method) }

          it "routes to #{expected_controller}" do
            expect(run_app).to eq(app_module.const_get(expected_controller))
          end
        end
      end
    end
  end

  describe 'pattern matching behavior' do
    let(:app_module) do
      Module.new.tap do |mod|
        routes_data = {
          'GET /users' => { method: 'get', responder: 'UsersController', path: '/users' },
          'POST /posts' => { method: 'post', responder: 'PostsController', path: '/posts' }
        }
        routes = instance_double(FlashAPI::Routes::RouteSet, paths: routes_data)
        mod.const_set(:Routes, routes)
        mod.const_set(:UsersController, Class.new)
        mod.const_set(:PostsController, Class.new)
      end
    end

    it 'uses pattern matching for route resolution' do
      get_request = instance_double(FlashAPI::BaseRequest, uri: '/users', request_method: 'GET')
      post_request = instance_double(FlashAPI::BaseRequest, uri: '/posts', request_method: 'POST')

      expect(described_class.run(get_request, app_module)).to eq(app_module::UsersController)
      expect(described_class.run(post_request, app_module)).to eq(app_module::PostsController)
    end
  end

  describe 'error handling edge cases' do
    let(:app_module) do
      Module.new.tap do |mod|
        routes = FlashAPI::Routes.draw do
          get '/test', to: 'TestController'
        end
        mod.const_set(:Routes, routes)
        mod.const_set(:TestController, Class.new)
      end
    end

    context 'with nil request method' do
      let(:request) { instance_double(FlashAPI::BaseRequest, uri: '/test', request_method: nil) }

      it 'raises NoRouteMatch' do
        expect { described_class.run(request, app_module) }.to raise_error(FlashAPI::NoRouteMatch)
      end
    end

    context 'with nil URI' do
      let(:request) { instance_double(FlashAPI::BaseRequest, uri: nil, request_method: 'GET') }

      it 'raises NoRouteMatch' do
        expect { described_class.run(request, app_module) }.to raise_error(FlashAPI::NoRouteMatch)
      end
    end
  end
end