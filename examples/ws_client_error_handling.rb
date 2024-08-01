require 'scale_rb'

begin
  ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |_client|
    raise 'Error'
  end
rescue StandardError => e
  p e.message # "Error"
end
