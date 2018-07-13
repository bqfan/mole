require 'openssl'

require (File.dirname(__FILE__) + '/../../spec_helper')
require 'mole/worker/entry'
require 'mole/worker/error'

describe "Mole::Worker::Entry#search" do

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

  it "should fail if basedn is not added." do
    @entry.clear
    expect(proc {
      @entry.search('dc=example,dc=com', :base_object, [], [:present, 'objectClass'])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should hit all entries under specified base object when scope is :wholeSubtree." do
    scope = :whole_subtree
    attributes = []
    filter = [:present, 'objectClass']
    expect(@entry.search('dc=com', scope, attributes, filter).length).to eq(6)
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(6)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, attributes, filter).length).to eq(3)
    expect(@entry.search('uid=sato,ou=People,dc=example,dc=com', scope, attributes, filter).length).to eq(1)
  end

  it "should fail if base object is not subtree of basedn." do
    expect(proc {
      @entry.search('dc=sample,dc=com', :single_level, [], [:present, 'objectClass'])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should fail if no entry is hit." do
    expect(proc {
      @entry.search('dc=tanaka,ou=People,dc=example,dc=com', :base_object, [], [:present, 'objectClass'])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should hit at most one entry if scope is :base_object." do
    scope = :base_object
    attributes = []
    filter = [:present, 'objectClass']
    expect(proc {
      @entry.search('dc=com', scope, attributes, filter)
    }).to raise_error(@error::NoSuchObjectError)
    expect(@entry.search('dc=example,dc=com', scope, attributes, filter).length).to eq(1)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, attributes, filter).length).to eq(1)
    expect(@entry.search('uid=sato,ou=People,dc=example,dc=com', scope, attributes, filter).length).to eq(1)
  end

  it "should hit itself and its first level children if scope is :single_level." do
    scope = :single_level
    filter = [:present, 'objectClass']
    expect(@entry.search('dc=example,dc=com', scope, [], filter).length).to eq(3)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], filter).length).to eq(3)
    expect(@entry.search('ou=Group,dc=example,dc=com', scope, [], filter).length).to eq(2)
    expect(@entry.search('uid=sato,ou=People,dc=example,dc=com', scope, [], filter).length).to eq(1)
  end

  it "should fetch attributes only specified." do
    scope = :base_object
    filter = [:present, 'objectClass']
    entry = @entry.search('uid=sato,ou=People,dc=example,dc=com', scope, ['uid', 'bar'], filter)[0]
    expect(entry.attributes['uid']).to eq(['sato'])
    expect(entry.attributes['bar']).to be_nil
    expect(entry.attributes['objectClass']).to be_nil
  end

  it "should fetch all attributes if empty attributes is specified." do
    scope = :base_object
    filter = [:present, 'objectClass']
    entry = @entry.search('dc=example,dc=com', scope, [], filter)[0]
    expect(entry.attributes[:dc]).to eq(['example'])
    expect(entry.attributes[:objectClass]).to eq(['organizationalUnit'])

    entry = @entry.search('uid=sato,ou=People,dc=example,dc=com', scope, [], filter)[0]
    expect(entry.attributes[:uid]).to eq(['sato'])
    expect(entry.attributes[:uidNumber]).to eq(['10001'])
    expect(entry.attributes[:objectClass]).to eq(['posixAccount', 'inetOrgPerson'])
  end

  it "should fetch all attributes if '*' is included in specified attributes." do
    scope = :base_object
    filter = [:present, 'objectClass']
    entry = @entry.search('dc=example,dc=com', scope, ['dc', '*'], filter)[0]
    expect(entry.attributes[:dc]).to eq(['example'])
    expect(entry.attributes[:objectClass]).to eq(['organizationalUnit'])

    entry = @entry.search('uid=sato,ou=People,dc=example,dc=com', scope, ['*'], filter)[0]
    expect(entry.attributes[:uid]).to eq(['sato'])
    expect(entry.attributes[:uidNumber]).to eq(['10001'])
    expect(entry.attributes[:objectClass]).to eq(['posixAccount', 'inetOrgPerson'])
  end

  it "should fetch no attribute if specified attributes is only '1.1'." do
    scope = :base_object
    filter = [:present, 'objectClass']
    dn = 'uid=sato,ou=People,dc=example,dc=com'
    @entry.modify(dn, [[:add, ["1.1", 'foo']]])
    entry = @entry.search('uid=sato,ou=People,dc=example,dc=com', scope, ['1.1'], filter)[0]
    expect(entry.attributes).to be_empty

    entry = @entry.search('uid=sato,ou=People,dc=example,dc=com', scope, ['1.1', 'bar'], filter)[0]
    expect(entry.attributes).to_not be_empty
  end

  it "should filter with present filter." do
    scope = :whole_subtree
    expect(@entry.search('dc=example,dc=com', scope, [], [:present, 'uid']).length).to eq(2)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], [:present, 'objectClass']).length).to eq(3)
    expect(@entry.search('uid=sato,ou=People,dc=example,dc=com', scope, [], [:present, 'uid']).length).to eq(1)
    expect(proc {
      @entry.search('dc=example,dc=com', scope, [], [:present, 'bar'])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should filter with equality match." do
    scope = :whole_subtree
    expect(@entry.search('dc=example,dc=com', scope, [], [:equality_match, ['objectClass', 'posixAccount']]).length).to eq(2)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], [:equality_match, ['uid', 'sato']]).length).to eq(1)
    expect(proc {
      @entry.search('ou=People,dc=example,dc=com', scope, [], [:equality_match, ['uid', 'tanaka']])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should filter with substring match." do
    scope = :whole_subtree
    expect(@entry.search('dc=example,dc=com', scope, [], [:substrings, ['objectClass', [[:initial, 'posix']]]]).length).to eq(3)
    expect(@entry.search('dc=example,dc=com', scope, [], [:substrings, ['objectClass', [[:initial, 'posix'], [:final, 'ount']]]]).length).to eq(2)
    expect(@entry.search('dc=example,dc=com', scope, [], [:substrings, ['ou', [[:any, 'o']]]]).length).to eq(2)
    expect(@entry.search('dc=example,dc=com', scope, [], [:substrings, ['uid', [[:final, 'ki']]]]).length).to eq(1)
    expect(proc {
      @entry.search('dc=example,dc=com', scope, [], [:substrings, ['foo', [[:any, 'bar']]]])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should filter with greaterOrEqual match." do
    scope = :whole_subtree
    expect(@entry.search('dc=example,dc=com', scope, [], [:greater_or_equal, ['uidNumber', '10001']]).length).to eq(2)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], [:greater_or_equal, ['uidNumber', '10002']]).length).to eq(1)
    expect(proc {
      @entry.search('ou=People,dc=example,dc=com', scope, [], [:greater_or_equal, ['uidNumber', '10003']])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should filter with lessOrEqual match." do
    scope = :whole_subtree
    expect(@entry.search('dc=example,dc=com', scope, [], [:less_or_equal, ['uidNumber', '10002']]).length).to eq(2)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], [:less_or_equal, ['uidNumber', '10001']]).length).to eq(1)
    expect(proc {
      @entry.search('ou=People,dc=example,dc=com', scope, [], [:less_or_equal, ['uidNumber', '10000']])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should treat approxMathch filter as equalityMatch." do
    scope = :whole_subtree
    expect(@entry.search('dc=example,dc=com', scope, [], [:approx_match, ['objectClass', 'posixAccount']]).length).to eq(2)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], [:approx_match, ['uid', 'sato']]).length).to eq(1)
    expect(proc {
      @entry.search('ou=People,dc=example,dc=com', scope, [], [:approx_match, ['uid', 'tanaka']])
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should treat extensible_match" do
    scope = :whole_subtree
    expect(@entry.search('dc=example,dc=com', scope, [], [:extensible_match, [:equality_match, 'objectClass', 'posixGroup']]).length).to eq(1)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], [:extensible_match, [:equality_match, nil, 'posixAccount']]).length).to eq(2)
    expect(@entry.search('dc=example,dc=com', scope, [], [:extensible_match, [nil, 'objectClass', 'organizationalUnit']]).length).to eq(3)
  end

  it "should treat and filter." do
    scope = :whole_subtree
    filter1 = [:present, 'objectClass']
    filter2 = [:greater_or_equal, ['uidNumber', '10002']]
    filter = [:and, [filter1, filter2]]
    expect(@entry.search('dc=example,dc=com', scope, [], filter).length).to eq(1)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], filter).length).to eq(1)
    expect(proc {
      @entry.search('ou=Group,dc=example,dc=com', scope, [], filter)
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should treat or filter." do
    scope = :whole_subtree
    filter1 = [:equality_match, ['objectClass', 'organizationalUnit']]
    filter2 = [:greater_or_equal, ['uidNumber', '10002']]
    filter = [:or, [filter1, filter2]]
    expect(@entry.search('dc=example,dc=com', scope, [], filter).length).to eq(4)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], filter).length).to eq(2)
    expect(proc {
      @entry.search('uid=sato,ou=People,dc=example,dc=com', scope, [], filter)
    }).to raise_error(@error::NoSuchObjectError)
  end

  it "should treat not filter." do
    scope = :whole_subtree
    expect(proc {
      @entry.search('dc=example,dc=com', scope, [], [:not, [:present, 'objectClass']])
    }).to raise_error(@error::NoSuchObjectError)
    expect(@entry.search('ou=People,dc=example,dc=com', scope, [], [:not, [:present, 'ou']]).length).to eq(2)
  end

  it "should ignore case to filter." do
    scope = :whole_subtree
    filter = [:present, 'objectclass']
    expect(@entry.search('dc=example,dc=com', scope, [], filter).length).to eq(6)
  end

  it "should ignore case to matching dn." do
    scope = :whole_subtree
    filter = [:present, 'objectclass']
    expect(@entry.search('dc=Example,dc=Com', scope, [], filter).length).to eq(6)
  end

  it "should hit BaseDN if search base is parent of BaseDN and scope is :single_level." do
    expect(@entry.search('dc=com', :single_level, [], [:present, 'objectclass'])[0].dn).to eq('dc=example,dc=com')
    expect(@entry.search('dc=com', :single_level, [], [:present, 'objectclass']).length).to eq(1)
  end
end
