require './lib/example02'

describe Core do 
  context "When testing the Core class" do 

    before do
      @parachain_dao = ParachainDAO.new("BlockDevRels", :kusama_coretime)
      puts @parachain_dao.to_s
      @user = User.new("Sasha", @parachain_dao)
      @core = Core.new(1, @parachain_dao)
      @core.autorenew
    end

    it "#autorenew" do 
      expect(@core.renewals_count).to be(1)
    end
  end
end