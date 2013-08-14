# Copyright 2013 Kinvey, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

redis = require 'redis'
url = require 'url'
Store = require './store'

RedisStore = module.exports = (options) ->
  this.connected = false
  this.options = options
  return

RedisStore.prototype.__proto__ = Store.prototype

RedisStore.prototype.connect = ->
  if this.options?.REDIS_URL?
    parsedUrl = url.parse this.options.REDIS_URL
    this.store = redis.createClient parsedUrl.port, parsedUrl.hostname
    this.store?.auth parsedUrl.auth.split(":")[1]
    this.store?.on 'error', (err) -> throw err
    this.connected = true

  else if this.options?.port? and this.options.hostname?
    this.store = redis.createClient this.options.port, this.options.hostname
    this.store?.auth this.options.password if this.options.password?
    this.store?.on 'error', (err) -> throw err
    this.connected = true

  else
    throw new Error "Missing Redis parameters: please specify hostname, port, and password"

RedisStore.prototype.disconnect = ->
  this.store?.quit()
  this.connected = false

RedisStore.prototype.isConnected = -> this.connected

RedisStore.prototype.set = (key, value) ->
  if key? and value?
    this.store?.set key, value
  else
    throw new Error "Both key and value must be specified"

RedisStore.prototype.del = (key) ->
  if key?
    this.store?.del key

RedisStore.prototype.setTTL = (key, ttlInSec=0) ->
  if key?
    this.store?.expire key, ttlInSec

RedisStore.prototype.getAllKeys = (callback) ->
  this.store?.keys '*', (err, replies) ->
    callback err, replies

RedisStore.prototype.clearAll = ->
  this.store?.flushdb()