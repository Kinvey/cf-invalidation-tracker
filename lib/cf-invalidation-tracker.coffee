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
invalidatejs = require 'invalidatejs'
Store = require './stores/store'
RedisStore = require './stores/redis-store'

module.exports = (options) ->
  # CloudFront allows for a maximum of 1000 files per invalidation request
  MAX_PATHS_PER_REQUEST = 1000

  throw new Error "Missing options" unless options?

  unless options.cf? and options.cf.secret_key? and options.cf.access_key? and options.cf.dist?
    throw new Error "Missing CloudFront secret key, access key, or distribution ID"

  if options.store?
    if options.store instanceof Store
      store = options.store
    else
      throw new Error "Options.store must be an instance of ./lib/stores/Store"
  else if options.redis?
    store = new RedisStore options.redis
  else
    throw new Error "Options must contain a store"

  {
    storeUrl: (url, ttlInSec=0) ->
      store.connect?() if store? and not store.isConnected?()
      if url.length > 2000 # Arbitrary length, I am not sure how long cloudfront actually permits the lengths to be
        console.log 'URL attmpted to be stored with too large of a length'
        return

      if url.indexOf '<' != -1 or url.indexOf '>' != -1
        console.log 'Url contains < or > characters which are not valid in a url'
        return

      store?.set url, 1
      store?.setTTL? url, ttlInSec if ttlInSec > 0


    setUrlTTL: (url, ttl) ->
      store.connect?() if store? and not store.isConnected?()
      if store?.setTTL?
        store?.setTTL url, ttl

    removeUrl: (url) ->
      store.connect?() if store? and not store.isConnected?()
      if store?.del?
        store?.del url

    disconnect: ->
      store?.disconnect?()

    sendInvalidation: ->
      store.connect?() if store? and not store.isConnected?()
      store?.getAllKeys (err, pathArray) ->
        if err?
          store.disconnect?()
          throw err

        if pathArray?.length > 0
          tracking = Math.ceil(pathArray.length/MAX_PATHS_PER_REQUEST)
          errorOccurred = false

          # Handle completion of the path invalidations
          handleCompletion = (err)->
            if err
              errorOccurred = true

            tracking--
            if tracking <= 0
              if errorOccurred
                console.log 'Did not clear redis tracking database because there was an error.'
              else
                # Clear all keys only on invalidation success
                store.clearAll()
                console.log 'Cleared redis database because there were no errors.'

              store.disconnect?()

          # Split into chunks of MAX_PATHS_PER_REQUEST
          for i in [0 .. pathArray.length] by MAX_PATHS_PER_REQUEST
            ijsConfig =
              resourcePaths: pathArray.slice i, i + MAX_PATHS_PER_REQUEST
              secret_key: options.cf.secret_key
              access_key: options.cf.access_key
              dist: options.cf.dist
              verbose: false

            console.log 'Sending invalidation to CloudFront... (' + ijsConfig.resourcePaths.length + ' paths)'
            invalidatejs ijsConfig, (err, status, body)->
              if err
                handleCompletion(true)
                console.log 'Error!', err, status, body
              else
                handleCompletion(false)
                console.log 'Success!', status

  }