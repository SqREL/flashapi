# frozen_string_literal: true

require_relative 'app'

# Rack configuration file for deploying with standard Rack servers
# Usage: rackup config.ru -p 3000

run FlashAPI.rack_app(MyApp)