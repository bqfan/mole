require (File.dirname(__FILE__) + '/../spec_helper')
require 'net/ldap'

describe "Net::LDAP#modify" do

  before :all do
    @server = Mole::Server.new(level: 'error')
    @t = @server.listen(async=true)

  end

  before do
    @server.clear

    @ldap = Net::LDAP.new
    @ldap.port = 3890
    @ldap.base = 'dc=example,dc=com'

    @ldap.open do |ldap|
      ldap.add(dn: 'dc=example,dc=com',
               attributes: {dc: "example", objectClass: "organizationalUnit"})
      ldap.add(dn: 'ou=Group,dc=example,dc=com',
               attributes: {ou: "Group", objectClass: "organizationalUnit"})
      ldap.add(dn: 'gid=user,ou=Group,dc=example,dc=com',
               attributes: {gid: "users", objectClass: "posixGroup", gidNumber: '10001'})
      ldap.add(dn: 'ou=People,dc=example,dc=com',
               attributes: {ou: "People", objectClass: "organizationalUnit"})
      ldap.add(dn: 'uid=sato,ou=People,dc=example,dc=com',
               attributes: {
                 uid: "sato", objectClass: ['posixAccount', 'inetOrgPerson'],
                 uidNumber: '10001', gidNumber: '10001',
                 mail: ['sato@example.com', 'sato@example.org', 'sato@example.net']})
      ldap.add(dn: 'uid=suzuki,ou=People,dc=example,dc=com',
               attributes: {
                 uid: "suzuki", objectClass: ['posixAccount', 'inetOrgPerson'],
                 uidNumber: '10002', gidNumber: '10002',
                 mail: ['suzuki@example.com', 'suzuki@example.org', 'suzuki@example.net']})
    end
  end

  after :all do
    @server.close
    @t.join
  end

  it "should add attributes." do
    @ldap.open do |ldap|
      dn = 'uid=sato,ou=People,dc=example,dc=com'
      ldap.modify(dn: dn, operations: [[:add, :mobile, ['000-0000-0000']]])
      expect(ldap.search(base: dn, attributes: ['mobile'])[0][:mobile]).to eq(['000-0000-0000'])
    end
  end

  it "should replace attributes." do
    @ldap.open do |ldap|
      dn = 'uid=sato,ou=People,dc=example,dc=com'
      ldap.modify(dn: dn, operations: [[:replace, :mail, ['sato@example.com']]])
      expect(ldap.search(base: dn, attributes: ['mail'])[0][:mail]).to eq(['sato@example.com'])

      ldap.modify(dn: dn, operations: [[:replace, :mail, ['sato@example.org', 'sato@example.net']]])
      expect(ldap.search(base: dn, attributes: ['mail'])[0][:mail]).to eq(['sato@example.org', 'sato@example.net'])

      ldap.modify(dn: dn, operations: [[:replace, :mail, []]])
      expect(ldap.search(base: dn, attributes: ['mail'])[0][:mail]).to be_empty
    end
  end

  it "should delete attributes." do
    @ldap.open do |ldap|
      dn = 'uid=sato,ou=People,dc=example,dc=com'
      ldap.modify(dn: dn, operations: [[:delete, :objectClass, ['inetOrgPerson']]])
      expect(ldap.search(base: dn, attributes: ['objectClass'])[0][:objectClass]).to eq(['posixAccount'])

      ldap.modify(dn: dn, operations: [[:delete, :mail, []]])
      expect(ldap.search(base: dn, attributes: ['mail'])[0][:mail]).to be_empty
    end
  end

  it "should do many operations at once." do
    @ldap.open do |ldap|
      dn = 'uid=sato,ou=People,dc=example,dc=com'
      ldap.modify(dn: dn,
                  operations: [
                      [:add, :mobile, ['000-0000-0000']],
                      [:add, :mail, 'sato@example.biz'],
                      [:replace, :mail, 'sato@example.net'],
                      [:delete, :gidNumber]
                  ])
      entry = ldap.search(base: dn, attributes: ['mail', 'mobile', 'gidNumber'])[0]
      expect(entry['mail']).to eq(['sato@example.net'])
      expect( entry['mobile']).to eq(['000-0000-0000'])
      expect(entry['gidNumber']).to be_empty
    end
  end

  it "should be atomic operation" do
    @ldap.open do |ldap|
      dn = 'uid=sato,ou=People,dc=example,dc=com'
      ldap.modify(dn: dn,
                  operations: [
                      [:add, :mobile, ['000-0000-0000']],
                      [:delete, :homedirectory]
                  ])
      entry = ldap.search(base: dn, attributes: ['mobile', 'homedirectory'])[0]
      expect(entry['mobile']).to be_empty
      expect(entry['homedirectory']).to be_empty
    end
  end
end

