# Proximo #

Proximo is an easily configurable proxy for developing locally against a remote server.

Why would you desire such a thing? I envy anyone who has never encountered a legacy application so mysterious and monstrous that a single development environment (configured before the dawn of recorded history) must be shared among all developers. Code changes must be manually uploaded to the shared development environment before they are confirmed to work. The environment starts to drift farther and farther away from what's in source control.

Proximo makes this situation far more tolerable by letting you work locally with static files (HTML, CSS, JavaScript). It is a tiny Sinatra app that serves local files if it finds them in the specified directory. Otherwise it acts as a proxy, forwarding incoming requests to a remote server and serving the result.


## Installation ##

1. Download or clone this repository.

2. Copy or rename proximo.example.yml to proximo.yml.

3. Customize proximo.yml.

4. Customize `hosts` file with the local hostnames required.

4. Start server with `sudo ruby proximo.rb`


## Configuration ##

This is a minimal configuration. Requests directed to local.foo.com (mapped to 127.0.0.1 in your hosts file) will use this configuration. The server attempts to serve the requested file from the docroot.  If not found, it forwards the request to the remote server.

```yaml
local.foo.com:
  docroot: ~/apps/foo
  proxy: www.foo.com
```

You can also specify that certain requests should always be forwarded to the remote server, even if they exist in the docroot. This is useful for JSP, ASP, PHP files that you cannot be served dynamically from your machine.

```yaml
local.foo.com:
  docroot: ~/apps/foo
  proxy: www.foo.com
  always_from_remote:
    - /time
    - *.php
```

If you are unforunate enough to need to forward requests to multiple remote hosts (we were) you can use this alternative format for specifying the remotes:

```yaml
local.foo.com:
  docroot: ~/apps/foo
  proxy: 
    default: www.foo.com
    others:
      - for: /articles/*
        use: localhost:3000
```

## Roadmap ##

This app was a quick hack that solved a real-life problem and saved lives.  But I'm not happy with the central configuration file, and the need to hack on your hosts file.  Here's what I'd like to improve:

- Package as a gem, with a `proximo` binary that accepts basic configuration (port, remote host, etc.) as command-line arguments.
- Allow more complex configuration to be versioned in a `.proximo` file that is automatically picked up by the Proximo binary.
- Refactor proxy to forward *all* HTTP headers automatically.
- Refactor to use Rack instead of Sinatra.
