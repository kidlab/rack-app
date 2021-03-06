module Rack::App::InstanceMethods

  require 'rack/app/instance_methods/core'
  require 'rack/app/instance_methods/http_control'
  require 'rack/app/instance_methods/payload'
  require 'rack/app/instance_methods/serve_file'
  require 'rack/app/instance_methods/streaming'

  include Rack::App::InstanceMethods::Core
  include Rack::App::InstanceMethods::HttpControl
  include Rack::App::InstanceMethods::Payload
  include Rack::App::InstanceMethods::ServeFile
  include Rack::App::InstanceMethods::Streaming

end
