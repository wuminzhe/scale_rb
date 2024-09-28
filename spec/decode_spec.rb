# frozen_string_literal: true

require 'scale_rb'
require 'json'

module ScaleRb
  RSpec.describe 'Decoding Tests' do
    # test :: Ti -> U8Array -> Any -> U8Array -> Types::Registry -> void
    def test(ti, bytes, value, registry)
      expect(
        ScaleRb::Codec.decode(ti, bytes, registry)
      ).to eql(
        [value, []]
      )

      # expect(
      #   ScaleRb::Codec.encode(ti, value, registry)
      # ).to eql(
      #   bytes
      # )
    end

    before(:all) do
      data = JSON.parse(File.open(File.join(__dir__, 'assets', 'substrate-types.json')).read)
      @registry = ScaleRb::PortableRegistry.new(data)

      # data = JSON.parse(File.open(File.join(__dir__, 'assets', './kusama-types.json')).read)
      # @kusama_registry = ScaleRb::PortableRegistry.new(data)
    end

    it 'can decode uint' do
      test(2, [0x45], 69, @registry)
    end

    it 'can decode array' do
      test(
        1,
        [0x12, 0x34, 0x56, 0x78] * 8,
        ScaleRb::Utils.hex_to_u8a('0x1234567812345678123456781234567812345678123456781234567812345678'),
        @registry
      )
    end

    it 'can decode sequence' do
      test(11, ScaleRb::Utils.hex_to_u8a('0x0c003afe'), [0, 58, 254], @registry)
    end

    # A single element tuple can be treated as the element.
    it 'can decode a single element tuple' do
      test(
        0,
        [0x12, 0x34, 0x56, 0x78] * 8,
        ScaleRb::Utils.hex_to_u8a('0x1234567812345678123456781234567812345678123456781234567812345678'),
        @registry
      )
    end

    it 'can decode composite 1' do
      test(
        8,
        [0x00, 0xe4, 0x0b, 0x54, 0x03, 0x00, 0x00, 0x00],
        { ref_time: 14_294_967_296 },
        @registry
      )
    end

    it 'can decode composite 2' do
      bytes = ScaleRb::Utils.hex_to_u8a(
        '0x'\
        '05000000000000000100000000000000142ba3d4e80000000000000000000000'\
        '0000000000000000000000000000000000000000000000000000000000000000'\
        '00000000000000000000000000000000'
      )

      value = {
        nonce: 5,
        consumers: 0,
        providers: 1,
        sufficients: 0,
        data: {
          free: 999_999_875_860,
          reserved: 0,
          misc_frozen: 0,
          fee_frozen: 0
        }
      }

      test(
        3,
        bytes,
        value,
        @registry
      )
    end

    # it 'can decode composite4' do
    #   bytes = ScaleRb::Utils.hex_to_u8a(
    #     '0x'\
    #     '020406010700f2052a017d01260000400d030000000000000000000000000000'\
    #     '00000000000000000000000000000001004617d470f847ce166019d19a794404'\
    #     '9ebb017400000000000000000000000000000000000000000000000000000000'\
    #     '00000000001019ff1d2100'
    #   )

    #   value = {
    #     V2: [
    #       {
    #         Transact: {
    #           origin_type: :SovereignAccount,
    #           require_weight_at_most: 5_000_000_000,
    #           call: {
    #             encoded: [
    #               38, 0, 0, 64, 13, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    #               0, 0, 0, 0, 0, 0, 1, 0, 70, 23, 212, 112, 248, 71, 206, 22, 96, 25, 209, 154, 121, 68, 4, 158, 187, 1, 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 25, 255, 29, 33, 0
    #             ]
    #           }
    #         }
    #       }
    #     ]
    #   }

    #   test(
    #     542,
    #     bytes,
    #     value,
    #     @kusama_registry
    #   )
    # end

    # it 'can decode unit' do
    #   test 161, [], [], @types
    # end

    # it 'can decode simple variant' do
    #   test(87, [0x01], :NonTransfer, @types)
    # end

    # it 'can decode tuple variant' do
    #   bytes = ScaleRb::Utils.hex_to_u8a('0x0200300422')
    #   value = { X2: [{ Parachain: 12 }, { PalletInstance: 34 }] }
    #   test(125, bytes, value, @kusama_types)
    # end

    # it 'can decode versioned xcm' do
    #   bytes = ScaleRb::Utils.hex_to_u8a(
    #     '0x020c000400010200e520040500170000d01309468e15011300010200e520040500170000d01309468e15010006010700f2052a01180a070c313233'
    #   )

    #   value = {
    #     V2: [
    #       {
    #         WithdrawAsset: [{
    #           id: {
    #             Concrete: {
    #               parents: 1,
    #               interior: {
    #                 X2: [
    #                   { Parachain: 2105 },
    #                   { PalletInstance: 5 }
    #                 ]
    #               }
    #             }
    #           },
    #           fun: {
    #             Fungible: 20_000_000_000_000_000_000
    #           }
    #         }]
    #       },
    #       {
    #         BuyExecution: {
    #           fees: {
    #             id: {
    #               Concrete: {
    #                 parents: 1,
    #                 interior: {
    #                   X2: [
    #                     { Parachain: 2105 },
    #                     { PalletInstance: 5 }
    #                   ]
    #                 }
    #               }
    #             },
    #             fun: { Fungible: 20_000_000_000_000_000_000 }
    #           },
    #           weight_limit: :Unlimited
    #         }
    #       },
    #       {
    #         Transact: {
    #           origin_type: :SovereignAccount,
    #           require_weight_at_most: 5_000_000_000,
    #           call: { encoded: [10, 7, 12, 49, 50, 51] }
    #         }
    #       }
    #     ]
    #   }

    #   test 542, bytes, value, @kusama_types
    # end
  end
end
