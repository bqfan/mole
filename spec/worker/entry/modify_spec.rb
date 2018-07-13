require 'openssl'

require (File.dirname(__FILE__) + '/../../spec_helper')
require 'mole/worker/entry'
require 'mole/worker/error'

describe "Mole::Worker::Entry#modify" do

  before :all do
    @entry = Mole::Worker::Entry
    @error = Mole::Worker::Error
    @filter = [:present, 'objectClass'] # Hit all entries
  end

  before do
    @entry.clear

    expect(@entry.add('dc=example,dc=com',
                      [ ['dc', ['example']],
                        ['objectClass', ['organizationalUnit']] ])).to be_truthy

    expect(@entry.add('ou=People,dc=example,dc=com',
                      [ ['ou', ['People']],
                        ['objectClass', ['organizationalUnit']] ])).to be_truthy

    expect(@entry.add('uid=sato,ou=People,dc=example,dc=com',
                      [ ['uid', ['sato']],
                        ['uidNumber', ['10001']],
                        ['objectClass', ['posixAccount', 'inetOrgPerson'],],
                        ['mail', ['sato@example.com', 'sato@example.net', 'sato@example.org']] ])).to be_truthy

    expect(@entry.add('uid=suzuki,ou=People,dc=example,dc=com',
                      [ ['uid', ['suzuki']],
                        ['uidNumber', ['10002']],
                        ['objectClass', ['posixAccount', 'inetOrgPerson']],
                        ['mail', ['suzuki@example.com', 'suzuki@example.net', 'suzuki@example.org']] ])).to be_truthy

    expect(@entry.add('ou=Group,dc=example,dc=com',
                      [ ['ou', ['Group']],
                        ['objectClass', ['organizationalUnit']] ])).to be_truthy

    expect(@entry.add('gid=users,ou=Group,dc=example,dc=com',
                      [ ['gid', ['users']],
                        ['objectClass', ['posixGroup']] ])).to be_truthy
  end

  it "should add attributes with add operation." do
    dn = 'uid=sato,ou=People,dc=example,dc=com'
    mobile = ['000-0000-0000', '111-1111-1111']
    @entry.modify(dn, [[:add, ["mobile", mobile]]])
    expect(@entry.search(dn, :base_object, ["mobile"], @filter)[0].attributes[:mobile]).to eq(mobile)

    new_mobile = ['222-2222-2222']
    @entry.modify(dn, [[:add, ["mobile", new_mobile]]])
    expect(@entry.search(dn, :base_object, ["mobile"], @filter)[0].attributes[:mobile]).to eq(mobile + new_mobile)
  end

  it "should delete attributes with delete operation." do
    dn = 'uid=sato,ou=People,dc=example,dc=com'
    @entry.modify(dn, [[:delete, ["mail", ['sato@example.net']]]])
    expect(@entry.search(dn, :base_object, ["mail"], @filter)[0].attributes[:mail]).to eq(['sato@example.com', 'sato@example.org'])
    @entry.modify(dn, [[:delete, ["mail", ['sato@example.org', 'sato@example.com']]]])
    expect(@entry.search(dn, :base_object, ["mail"], @filter)[0].attributes[:mail]).to be_nil

    dn = 'uid=suzuki,ou=People,dc=example,dc=com'
    @entry.modify(dn, [[:delete, ["mail", []]]])
    expect(@entry.search(dn, :base_object, ["mail"], @filter)[0].attributes[:mail]).to be_nil
  end

  it "shoule fail to delete unexisted attributes." do
    dn = 'uid=sato,ou=People,dc=example,dc=com'
    expect(proc {
      @entry.modify(dn, [[:delete, ["mail", ['sato@example.biz']]]])
    }).to raise_error(@error::NoSuchAttributeError)

    expect(proc {
      @entry.modify(dn, [[:delete, ["mobile", ['000-0000-0000']]]])
    }).to raise_error(@error::NoSuchAttributeError)

    expect(proc {
      @entry.modify(dn, [[:delete, ["homedirectory", []]]])
    }).to raise_error(@error::NoSuchAttributeError)
  end

  it "should replace attributes with replace operation." do
    dn = 'uid=sato,ou=People,dc=example,dc=com'
    @entry.modify(dn, [[:replace, ["mail", ['sato@example.info']]]])
    expect(@entry.search(dn, :base_object, ["mail"], @filter)[0].attributes[:mail]).to eq(['sato@example.info'])
    @entry.modify(dn, [[:replace, ["mail", []]]])
    expect(@entry.search(dn, :base_object, ["mail"], @filter)[0].attributes[:mail]).to be_nil
    @entry.modify(dn, [[:replace, ["mobile", ['000-0000-0000']]]])
    expect(@entry.search(dn, :base_object, ["mobile"], @filter)[0].attributes[:mobile]).to eq(['000-0000-0000'])
    @entry.modify(dn, [[:replace, ["homedirectory", []]]]) # Check no error is raised.
  end

  it "should treat many operations at once." do
    dn = 'uid=sato,ou=People,dc=example,dc=com'
    mobile = ['000-0000-0000', '111-1111-1111']
    new_mobile = ['222-2222-2222']
    homedirectory = ['/home/sato']
    new_mail = ['sato@example.biz']
    @entry.modify(dn,
                         [
                           [:add, ["mobile", mobile]],
                           [:add, ["homedirectory", homedirectory]],
                           [:add, ["mail", new_mail]],
                           [:delete, ['mail', []]],
                           [:replace, ["mobile", new_mobile]]
                         ])
    entry = @entry.search(dn, :base_object, ['mail', 'homedirectory', 'mobile'], @filter)[0]
    expect(entry.attributes['mobile']).to eq(new_mobile)
    expect(entry.attributes['homedirectory']).to eq(homedirectory)
    expect(entry.attributes['mail']).to be_nil
  end

  it "should be atomic operation." do
    dn = 'uid=sato,ou=People,dc=example,dc=com'
    mobile = ['000-0000-0000', '111-1111-1111']
    expect(proc {
      @entry.modify(dn,
                           [
                             [:add, ["mobile", mobile]],
                             [:delete, ['homedirectory', []]],
                           ])
    }).to raise_error(@error::NoSuchAttributeError)
    expect(@entry.search(dn, :base_object, ['mail', 'homedirectory', 'mobile'], @filter)[0].attributes['mobile']).to be_nil
  end

  it "should treat tree dn." do
    dn = 'ou=People,dc=example,dc=com'
    foo = ['bar', 'baz']
    @entry.modify(dn, [[:add, ["foo", foo]]])
    expect(@entry.search(dn, :base_object, [], @filter)[0].attributes['foo']).to eq(foo)
    expect(@entry.search(dn, :whole_subtree, [], @filter).length).to eq(3)
  end

  it "should modify base dn." do
    dn = 'dc=example,dc=com'
    @entry.modify(dn, [[:replace, ['objectClass', ['posixGroup']]]])
    expect(@entry.search(dn, :base_object, [], @filter)[0].attributes['objectClass']).to eq(['posixGroup'])
    expect(@entry.search(dn, :whole_subtree, [], @filter).length).to eq(6)
  end
end
