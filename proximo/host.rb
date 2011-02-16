module Proximo
  class Host
    attr_accessor :name, :remote_host, :handlers

    def initialize(name)
      @name = name
      @aliases = []
      @indexes = ['index.html']
      @handlers = []
    end
    
    def root(path=nil)
      @root = path if path
      @root
    end

    def fetch_from(host)
      @remote_host = host
    end
    
    def aliases(*args)
      @aliases = args if !args.empty?
      @aliases
    end
    
    def indexes(*args)
      if args.first == :none
        @indexes = []
      elsif !args.empty?
        @indexes = args
      end
      @indexes
    end
    
    def handle(pattern, &block)
      @handlers << Proximo::Handler.new(block, pattern)
    end
  end
end
