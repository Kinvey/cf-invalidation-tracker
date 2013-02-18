should = require 'should'
Store = require '../lib/stores/store'

describe 'cf-invalidation-tracker', ->
  CF_INFO_ERROR = "Missing CloudFront secret key, access key, or distribution ID"

  store = {}

  TestStore = -> return

  TestStore.prototype.__proto__ = Store.prototype

  TestStore.prototype.set = (key, value) -> store[key] = value
  TestStore.prototype.getAllKeys = (callback) -> callback null, []
  TestStore.prototype.clearAll = -> store = {}

  cf = { secret_key: "S", access_key: "A", dist: "123" }
  testStore = new TestStore()

  describe 'module parameters', ->
    it 'throws when no options are passed in', ->
      (-> require('../index')).should.throw

    it 'throws when missing CloudFront parameters', ->
      (-> require('../index')({ cf: {} })).should.throw CF_INFO_ERROR
      (-> require('../index')({ cf: { secret_key: true } })).should.throw CF_INFO_ERROR
      (-> require('../index')({ cf: { secret_key: true, access_key: true } })).should.throw CF_INFO_ERROR
      (-> require('../index')({ cf: { secret_key: true, access_key: true, dist: true } })).should.not.throw CF_INFO_ERROR
    
    it 'throws when missing a redis parameter', ->
      (-> require('../index')({ cf: cf })).should.throw "Options must contain a store"
      (-> require('../index')({ cf: cf, redis: true })).should.not.throw()
    
    it 'throws when missing a valid store parameter', ->
      (-> require('../index')({ cf: cf, store: {} })).should.throw "Options.store must be an instance of ./lib/stores/Store"
      (-> require('../index')({ cf: cf, store: testStore })).should.not.throw
  
  TestStore.prototype.connect = -> this.connected = true
  TestStore.prototype.disconnect = -> this.connected = false

  TestStore.prototype.isConnected = -> this.connected || false
  TestStore.prototype.del = (key) -> store[key] = undefined
  TestStore.prototype.setTTL = (key, ttlInSec=0) -> store[key] = ttlInSec

  describe 'exported functions', ->
    invl = require('../index') { cf: cf, store: testStore }

    testUrl = "/some-url.ext"

    it 'should not be connected initially', ->
      testStore.isConnected().should.be.false

    it 'stores a URL', ->
      store.should.not.have.property testUrl
      invl.storeUrl testUrl
      store.should.have.property testUrl, 1

    it 'should be connected after the first command', ->
      testStore.isConnected().should.be.true

    it 'stores a URL with a TTL', ->
      invl.storeUrl testUrl, 42
      store.should.have.property testUrl, 42

    it 'removes a URL', ->
      invl.removeUrl testUrl
      store.should.not.have.property testUrl
    
    it 'sets a TTL for a URL', ->
      invl.setUrlTTL testUrl, 100
      store.should.have.property testUrl, 100

    it 'disconnects', ->
      invl.disconnect()
      testStore.isConnected().should.be.false

    describe 'sendInvalidation', ->
      testStore.clearAll()

      it 'connects if disconnected', ->
        invl.sendInvalidation()
        testStore.isConnected().should.be.true

      it 'throws and disconnects when it cannot retrieve keys', ->
        TestStore.prototype.getAllKeys = (callback) -> callback new Error("Error!"), null
        (-> invl.sendInvalidation()).should.throw()
        testStore.isConnected().should.be.false

      it 'doesn\'t call clearAll when provided with an empty path array', ->
        TestStore.prototype.getAllKeys = (callback) -> callback null, []
        store["someKey"] = 1
        invl.sendInvalidation()
        store.should.have.property "someKey"

      it 'calls clearAll and disconnects when trying to send non-empty path array', ->
        TestStore.prototype.getAllKeys = (callback) -> callback null, ["/a"]
        store["someKey"] = 1
        invl.sendInvalidation()
        store.should.not.have.property "someKey"
        testStore.isConnected().should.be.false