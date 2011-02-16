require 'proximo/server'
require 'proximo/host'
require 'proximo/handler'
require 'proximo/file'



def port(number)
  Proximo.server.port = number
end

def host(name, &block)
  host = Proximo::Host.new(name)
  host.instance_eval(&block)
  Proximo.server.register(host)
end

at_exit { Proximo.server.start }
