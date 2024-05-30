require "scale_rb"

methods = ScaleRb::HttpClient.rpc_methods("http://127.0.0.1:9944")
puts methods

# TODO - WS connection
