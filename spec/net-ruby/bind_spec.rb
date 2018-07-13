require (File.dirname(__FILE__) + '/../spec_helper')
require 'net/ldap'

describe "Net::LDAP#bind" do

  before :all do
    @server = Mole::Server.new(level: "error")
    @t = @server.listen(async=true)
  end

  after :all do
    @server.close
    @t.join
  end

  it "should be succeeded with annonymous auth." do
    ldap = Net::LDAP.new
    ldap.port = 3890
    expect(ldap.bind).to be_truthy
  end

end
