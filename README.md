### The problem

CloudFront does not offer a way to invalidate resource paths using wildcards. In order to send an invalidation request, you must specify the exact path to any resource. How do you know which paths are in your CloudFront cache, in order to invalidate them?

### A solution

`cf-invalidation-tracker` uses a local cache to keep track of every URL that is requested (hopefully, by CloudFront) from your server. Later, you can call a command that compiles an invalidation request from these URLs, sends it to CloudFront, and flushes the cache.


## Module options

The following options can/must be passed to `cf-invalidation-tracker`:

### CloudFront variables

In order to connect to CloudFront, you will need to pass the following options to `cf-invalidation-tracker`:

```
{ cf: {
    secret_key: your-secret-key,
    access_key: your-access-key,
    dist: your-CloudFront-distribution-ID
  }
}
```

### URL store

`cf-invalidation-tracker` allows you to use any type of store for maintaining the URL cache locally. The store you use must extend `Store`, located at `/lib/stores/store.coffee`. The extending store must implement the `set`, `getAllKeys` and `clearAll` methods, and can optionally implement `connect`, `disconnect`, `del` and `setTTL` to support richer functionality. A description of each function can be found in the Store file. After you have implemented a store, pass an instance of it, in an object named "store", as an option:

```coffeescript
invl = require('cf-invalidation-tracker')({ cf: { ... }, store: new MyStore() })
```

In our code, which runs on [Heroku](http://www.heroku.com/), we used Redis To Go (an in-memory object store) to maintain the cache. Along with other benefits, Redis offers a simple way to set a TTL for each cached URL. We have included a store implementation for Redis, which you can use as-is, or as an example of how to implement your own version. In order to use our Redis store, simply pass in a "redis" object as an option. This object can contain either a `REDIS_URL` parameter:

```coffeescript
invl = require('cf-invalidation-tracker')({ cf: { ... }, redis: { REDIS_URL: your-redis-url } })
```

or the `port`, `hostname` and (optionally) `password` for a redis connection:

```coffeescript
invl = require('cf-invalidation-tracker')({ cf: { ... }, redis: { port: some-port, hostname: some-host-name, password: some-password } })
```


## Usage

`cf-invalidation-tracker` exposes the following functions. Before doing anything else, all functions check whether `store.isConnected` is implemented and returns false, and if so, call `store.connect` if the function is implemented.

* `storeUrl(url, ttlInSec)` - calls `store.set` to store a URL. The `ttlInSec` argument is optional, and can use used to store a URL and set its TTL in one command.
* `setUrlTTL(url, ttlInSec)` - calls `store.setTTL` to set the expiration time, in seconds, of a URL.
* `removeUrl(url)` - calls `store.del` to remove a URL.
* `disconnect()` - calls `store.disconnect` to disconnect from the store.
* `sendInvalidation()` - gets all keys from the store using `store.getAllKeys`, sends them in batches of 1000 (max paths per request allowed by AWS), clears the cache using `store.clearAll`, then disconnects using `store.disconnect` (if that function is implemented by the store).


## Output

If the invalidation request was successful, the log will show:

```
Invaliding AWS... (x paths)
Success! 201
```

If it was unsuccessful, the log will show the error message sent by CloudFront.


## Example

The following is an example of using the utility in your server code. In the example, our Redis store is used.

### Requirements

You must have Redis To Go installed. On Heroku, this can be added to your app as a free add-on (https://addons.heroku.com/redistogo).

#### Environment variables

Once you have installed Redis To Go, the following environment variable should become available:
* REDISTOGO_URL

### Server code

First, connect to the Redis To Go server. We used environment variables to store the AWS connection information.

```coffeescript
# RedisToGo client setup
invl = require('cf-invalidation-tracker') { cf: { secret_key: process.env.AWS_SECRET_KEY, access_key: process.env.AWS_ACCESS_KEY, dist: process.env.CF_DIST }, redis: { REDIS_URL: process.env.REDISTOGO_URL } }
```

Then, add middleware that stores the URLs in redis. This is a simple example for [Express](http://expressjs.com/):

```coffeescript
app.use (req, res, next)->
  next()
  invl.storeUrl req.url
```

Alternatively, in order to set an expiration time for the cached URL, you can pass a TTL (in seconds):

```coffeescript
app.use (req, res, next)->
  next()
  invl.storeUrl req.url 60*60*24  # 24 hours
```

In our code, we remove invalid URLs from the cache in our 404 (not found) handler:

```coffeescript
app.use (req, res)->
    invl.removeUrl req.url
    # handle 404 page rendering
```

### Cakefile

To send the invalidation to CF, we define a task in a Cakefile.

```coffeescript
task 'invalidateCF', 'invalidate cached CloudFront paths', ->
  return unless process.env.REDISTOGO_URL?

  # RedisToGo client setup
  invl = require('cf-invalidation-tracker') { cf: { secret_key: process.env.AWS_SECRET_KEY, access_key: process.env.AWS_ACCESS_KEY, dist: process.env.CF_DIST }, redis: { REDIS_URL: process.env.REDISTOGO_URL } }

  # Invalidate any CF-cached files
  invl.sendInvalidation()
```

Since we use Heroku, this allows us to remotely execute the task by calling:

```
heroku run cake invalidateCF --app your-app-name
```

## Testing

To run the included [mocha](http://mochajs.org/) tests, once you have included `cf-invalidation-tracker` in your `package.json` file and installed with `npm install`, run:

```
npm test cf-invalidation-tracker
```
