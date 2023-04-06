# frozen_string_literal: true

require 'scale_rb'
require 'json'

RSpec.describe PortableCodec do
  before(:all) do
    types = JSON.parse(File.open(File.join(__dir__, 'assets', 'substrate-types.json')).read)
    @registry = types.map { |type| [type['id'], type['type']] }.to_h

    kusama_types = JSON.parse(File.open(File.join(__dir__, 'assets', './kusama-types.json')).read)
    @kusama_registry = kusama_types.map { |type| [type['id'], type['type']] }.to_h
  end

  it 'can decode fixed uint' do
    value, remaining_bytes = PortableCodec.decode 2, [0x45], @registry
    expect(value).to eql(69)
    expect(remaining_bytes).to eql([])
  end

  it 'can decode array' do
    value, remaining_bytes = PortableCodec.decode 1, [0x12, 0x34, 0x56, 0x78] * 8 + [0x78], @registry
    expect(value).to eql([0x12, 0x34, 0x56, 0x78] * 8)
    expect(remaining_bytes).to eql([0x78])
  end

  it 'can decode sequence' do
    value, remaining_bytes = PortableCodec.decode 11, '0x0c003afe'.to_bytes, @registry
    expect(value).to eql([0, 58, 254])
    expect(remaining_bytes).to eql([])
  end

  it 'can decode composite1' do
    # AccountId32
    value, remaining_bytes = PortableCodec.decode 0, [0x12, 0x34, 0x56, 0x78] * 8, @registry
    expect(value).to eql(
      [0x12, 0x34, 0x56, 0x78] * 8
    )
    expect(remaining_bytes).to eql([])
  end

  it 'can encode composite1' do
    # AccountId32
    bytes = PortableCodec.encode 0, [0x12, 0x34, 0x56, 0x78] * 8, @registry
    expect(bytes).to eql(
      [0x12, 0x34, 0x56, 0x78] * 8
    )
  end

  it 'can decode composite2' do
    # has name
    bytes = [0x00, 0xe4, 0x0b, 0x54, 0x03, 0x00, 0x00, 0x00]
    value, = PortableCodec.decode 8, bytes, @registry
    expect(value).to eql({
                           ref_time: 14_294_967_296
                         })

    # empty fields
    value, = PortableCodec.decode 161, [], @registry
    expect(value).to eql([])
  end

  it 'can decode composite3' do
    # AccountInfo
    bytes =
      '0x05000000000000000100000000000000142ba3d4e80000000000000000000000'\
        '0000000000000000000000000000000000000000000000000000000000000000'\
        '00000000000000000000000000000000'.to_bytes

    value, = PortableCodec.decode 3, bytes, @registry
    expect(value).to eql({
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
                         })
  end

  it 'can decode composite4' do
    # VersionedXcm
    bytes =
      '0x020406010700f2052a017d01260000400d030000000000000000000000000000'\
        '00000000000000000000000000000001004617d470f847ce166019d19a794404'\
        '9ebb017400000000000000000000000000000000000000000000000000000000'\
        '00000000001019ff1d2100'.to_bytes
    value, = PortableCodec.decode 542, bytes, @kusama_registry
    expect =
      {
        V2: [
          {
            Transact: {
              origin_type: 'SovereignAccount',
              require_weight_at_most: 5_000_000_000,
              call: {
                encoded: [
                  38, 0, 0, 64, 13, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                  0, 0, 0, 0, 1, 0, 70, 23, 212, 112, 248, 71, 206, 22, 96, 25, 209, 154, 121, 68, 4, 158, 187,
                  1, 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                  0, 0, 0, 0, 16, 25, 255, 29, 33, 0
                ]
              }
            }
          }
        ]
      }
    expect(value).to eql(expect)
  end

  it 'can decode tuple' do
    bytes =
      '0x12345678123456781234567812345678123456781234567812345678123456780bfeffffffffffff0000000000000000'.to_bytes
    # tuple: [0, 6]
    value, remaining_bytes = PortableCodec.decode 55, bytes, @registry
    expect(value).to eql(
      [
        '0x1234567812345678123456781234567812345678123456781234567812345678'.to_bytes,
        18_446_744_073_709_551_115 # u128
      ]
    )
    expect(remaining_bytes).to eql([])
  end

  it 'can decode variant' do
    value, remaining_bytes = PortableCodec.decode 87, [0x01, 0x02], @registry
    expect(value).to eql('NonTransfer')
    expect(remaining_bytes).to eql([0x02])
  end

  it 'can encode variant' do
    bytes = PortableCodec.encode(87, 'NonTransfer', @registry)
    expect(bytes).to eql([0x01])
  end

  # kusama registry 125 - Junctions
  it 'can decode variant with tuple' do
    value, remaining_bytes = PortableCodec.decode 125, "0x0200300422".to_bytes, @kusama_registry
    expect(value).to eql({:X2=>[{:Parachain=>12}, {:PalletInstance=>34}]})
    expect(remaining_bytes).to eql([])
  end

  it 'can decode versioned xcm' do
    bytes = "0x020c000400010200e520040500170000d01309468e15011300010200e520040500170000d01309468e15010006010700f2052a01180a070c313233".to_bytes
    value, remaining_bytes = PortableCodec.decode 542, bytes, @kusama_registry
    expected = {:V2=>[{:WithdrawAsset=>[{:id=>{:Concrete=>{:parents=>1, :interior=>{:X2=>[{:Parachain=>2105}, {:PalletInstance=>5}]}}}, :fun=>{:Fungible=>20000000000000000000}}]}, {:BuyExecution=>{:fees=>{:id=>{:Concrete=>{:parents=>1, :interior=>{:X2=>[{:Parachain=>2105}, {:PalletInstance=>5}]}}}, :fun=>{:Fungible=>20000000000000000000}}, :weight_limit=>"Unlimited"}}, {:Transact=>{:origin_type=>"SovereignAccount", :require_weight_at_most=>5000000000, :call=>{:encoded=>[10, 7, 12, 49, 50, 51]}}}]}
    puts JSON.pretty_generate(expected)
    expect(value).to eql(expected)
  end
end
