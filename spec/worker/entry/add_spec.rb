require 'openssl'

require (File.dirname(__FILE__) + '/../../spec_helper')
require 'mole/worker/entry'
require 'mole/worker/error'

describe "Mole::Worker::Entry#add" do

  before :all do
    @entry =  Mole::Worker::Entry
    @error =  Mole::Worker::Error
  end

  before do
    @entry.clear
  end

  it "should succeed to add basedn and child entries." do
    expect(@entry.add('dc=sample,dc=com',
               [ ['dc', ['sample']],
                 ['objectclass', ['organizationalUnit']] ])).to be_truthy
    expect(@entry.add('ou=People,dc=sample,dc=com',
               [ ['ou', ['People']],
                 ['objectclass', ['organizationalUnit']] ])).to be_truthy
    expect(@entry.add('uid=sato,ou=People,dc=sample,dc=com',
               [ ['uid', ['sato']],
                 ['objectclass', ['posixAccount', 'inetOrgPerson']] ])).to be_truthy
    expect(@entry.add('ou=Group,dc=sample,dc=com',
               [ ['ou', ['Group']],
                 ['objectclass', ['organizationalUnit']] ])).to be_truthy
    expect(@entry.add('gid=users,ou=Group,dc=sample,dc=com',
               [ ['gid', ['users']],
                 ['objectClass', ['posixGroup']] ])).to be_truthy
    expect(@entry.add('uid=suzuki,ou=People,dc=sample,dc=com',
               [ ['uid', ['suzuki']],
                 ['objectclass', ['posixAccount', 'inetOrgPerson']] ])).to be_truthy
  end

  it "should fail to add duplicated entries." do
    expect(@entry.add('dc=sample,dc=com',
               [ ['dc', ['sample']],
                 ['objectclass', ['organizationalUnit']] ])).to be_truthy
    expect(proc {
      expect(@entry.add('dc=sample,dc=com',
                 [ ['dc', ['sample']],
                   ['objectclass', ['organizationalUnit']] ])).to be_truthy
    }).to raise_error(@error::EntryAlreadyExistsError)
    expect(@entry.add('ou=People,dc=sample,dc=com',
               [ ['ou', ['People']],
                 ['objectclass', ['organizationalUnit']] ])).to be_truthy
    expect(proc {
      expect(@entry.add('ou=People,dc=sample,dc=com',
                 [ ['ou', ['People']],
                   ['objectclass', ['organizationalUnit']] ])).to be_truthy
    }).to raise_error(@error::EntryAlreadyExistsError)
  end

  it "should fail if parent dn doesn't exist." do
    expect(@entry.add('dc=sample,dc=com',
               [ ['dc', ['sample']],
                 ['objectclass', ['organizationalUnit']] ])).to be_truthy
    expect(proc {
      expect(@entry.add('uid=sato,ou=People,dc=sample,dc=com',
                 [ ['uid', ['sato']],
                   ['objectclass', ['posixAccount', 'inetOrgPerson']] ])).to be_truthy
    }).to raise_error(@error::UnwillingToPerformError)
  end
end
