# I own a DAO
# I need one or more cores to run it
# Each core costs x KSM per month
# Write software to manage the cores

class User
  def initialize(name, parachain_dao)
    @name = name
    @parachain_dao = parachain_dao
  end

  attr_accessor :name, :parachain_dao
end

class ParachainDAO
  def initialize(name, relay_chain)
    @name = name
    @relay_chain = relay_chain
    self.to_s
  end

  attr_accessor :name, :relay_chain

  def to_s
    "Created parachain DAO #{@name} on #{@relay_chain}"
  end
end

class Core
  def initialize(id, parachain_dao)
    @id = id
    @parachain_dao = parachain_dao
    @renewals_count = 0

    puts "Created core with #{@id}"
  end

  attr_accessor :id, :parachain_dao, :renewals_count

  def autorenew
    # poll for when able to renew when interlude period starts
    # renew when ready
    if is_ready_to_renew? self.id then
      self.renew
    end

    # TODO - emit event notification when renewed until to watch
  end

  def is_ready_to_renew?(core_id)
    # TODO - RPC call to broker pallet
    sleep 2
    true
  end

  def renew
    # poll for when markets change above threshold
    if met_market_threshold? then
      # TODO - check sufficient balance
      # TODO - RPC call to broker pallet to renew
      puts "Renewed core id #{@id} for parachain DAO #{@parachain_dao.name} on #{@parachain_dao.relay_chain}"
      self.renewals_count += 1
      true
    end
  end

  def met_market_threshold?
    # TODO - poll market conditions
    true
  end
end
