require 'openssl'

require (File.dirname(__FILE__) + '/../../spec_helper')
require 'mole/worker/entry'
require 'mole/worker/error'

describe "Mole::Worker::Entry#del" do

  before :all do
    @entry = Mole::Worker::Entry
    @error = Mole::Worker::Error
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
                 ['objectClass', ['posixAccount', 'inetOrgPerson']] ])).to be_truthy

    expect(@entry.add('uid=suzuki,ou=People,dc=example,dc=com',
               [ ['uid', ['suzuki']],
                 ['uidNumber', ['10002']],
                 ['objectClass', ['posixAccount', 'inetOrgPerson']] ])).to be_truthy

    expect(@entry.add('ou=Group,dc=example,dc=com',
               [ ['ou', ['Group']],
                 ['objectClass', ['organizationalUnit']] ])).to be_truthy

    expect(@entry.add('gid=users,ou=Group,dc=example,dc=com',
               [ ['gid', ['users']],
                 ['objectClass', ['posixGroup']] ])).to be_truthy
  end

  it "should delete leaf dn." do
    filter = [:present, 'objectClass']
    scope = :whole_subtree
    attributes = []
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(6)
    expect(@entry.del('uid=suzuki,ou=People,dc=example,dc=com')).to be_truthy
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(5)
  end

  it "should fail unless specified dn is a leaf." do
    filter = [:present, 'objectClass']
    scope = :whole_subtree
    attributes = []
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(6)
    expect(proc {
      expect(@entry.del('ou=People,dc=example,dc=com')).to be_truthy
    }).to raise_error(@error::NotAllowedOnNonLeafError)
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(6)
  end

  it "should fail unless specified dn is not." do
    filter = [:present, 'objectClass']
    scope = :whole_subtree
    attributes = []
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(6)
    expect(proc {
      expect(@entry.del('uid=katoou=People,dc=example,dc=com')).to be_truthy
    }).to raise_error(@error::NoSuchObjectError)
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(6)
  end

  it "should succeed after all leaves are deleted." do
    filter = [:present, 'objectClass']
    scope = :whole_subtree
    attributes = []
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(6)
    expect(@entry.del('uid=sato,ou=People,dc=example,dc=com')).to be_truthy
    expect(@entry.del('uid=suzuki,ou=People,dc=example,dc=com')).to be_truthy
    expect(@entry.del('ou=People,dc=example,dc=com')).to be_truthy
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(3)
  end

end
