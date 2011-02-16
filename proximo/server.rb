require 'singleton'
require 'rubygems'
require 'rack'


module Proximo
  class Server
    include Singleton
    
    attr_accessor :port, :hosts
    
    def initialize
      @hosts ||= {}
    end

    def register(host)
      # register a host so it can be looked up by its name or its aliases
      @hosts[host.name] = host 
      host.aliases.each { |a| @hosts[a] = host }
    end

    def start
      server = self
      app = Rack::Builder.new do
        # use Rack::Middleware here
        run server
      end

      # TODO: add support for any Rack-compliant server
      Rack::Handler::Mongrel.run app, :Port => self.port
    end

    def call(env)
      # create these once per request, and share among handlers
      request = Rack::Request.new(env)
      response = Rack::Response.new
      
      host = self.hosts[request.host]
      path = request.path_info
      handled = false      
      
      if !host.nil?
        host.handlers.each do |handler|
          if handler.matches?(path)
            handler.execute(request, response)
            handled = true
            break # TODO: support multiple handlers in 1 request
          end
        end
      end
      
      if !handled
        Proximo::Handler.default.execute(request, response)
      end
        
      response.finish
    end    
  end

  # convenience method to get singleton instance of Proximo::Server
  def Proximo.server
    Proximo::Server.instance
  end
end
