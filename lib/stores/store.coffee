Store = module.exports = -> {}


## Mandatory

# Add a key to the store.
Store.prototype.set = (key, value) ->
  throw new Error "Missing 'set' implementation!"

# Retrieve all keys from the store. When finished, call the callback, which accepts the parameters (err, pathArray), with the result (an array of strings).
Store.prototype.getAllKeys = (callback) ->
  throw new Error "Missing 'getAllKeys' implementation!"

# Clear all keys from the store.
Store.prototype.clearAll = ->
  throw new Error "Missing 'clearAll' implementation!"


## Optional

# Connect to the store.
Store.prototype.connect = -> {}

# Disconnect from the store.
Store.prototype.disconnect = -> {}

# Return true if a connection to the store exists, false otherwise.
Store.prototype.isConnected = -> {}

# Delete a key from the store.
Store.prototype.del = (key) -> {}

# Set the TTL, in seconds, of a key.
Store.prototype.setTTL = (key, ttlInSec=0) -> {}