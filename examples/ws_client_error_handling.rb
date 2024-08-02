require 'scale_rb'

begin
  ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |_client|
    raise 'MyError'
  end
rescue StandardError => e
  p e.message # "MyError"
end
