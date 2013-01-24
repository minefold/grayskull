require 'bundler'
require './app'

use Bugsnag::Rack
run Sinatra::Application
