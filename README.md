# Suj Pusher Server

This is a simple but enterprise level pusher server that can push notifications to iOS and Android devices using the APN and GCM push services respectively.

## Features

- Support both APN and GCM push services with a simple unified API interface.
- Keep persistent connections to APN following Apple recommendation.
- Use redis pub/sub mechanism for real time push notifications. No polling.
- No need to set APN certificates or GCM api keys in configuration files or pusher startup. These are sent in a per request basis. This allows support for multiple APN certs and GCM api keys in a single Pusher instance.
- EventMachine based to handle in the order of thousands of push requests per second.

## Installation

Via gems simply install the suj-pusher gem on your system:

```sh
gem install suj-pusher
```

or download the source via git:

```
git clone https://github.com/sujrd/suj-pusher.git
```

after cloning the gem make sure to run bundle install to install the dependencies:

```
cd suj-pusher
bundle install
```

## Usage

To run the server simply run the pusher daemon:

```
pusher start|stop|restart|status  <options>
```

options:
  - -H <redis host>: The redis server host or IP address where push messages are stored. Defaults to localhost.
  - -P <redis port>: Port number of the redis server where push messages are stored. Defaults to 6379.
  - -b <redis db>: The database number on the redis server to connect to. Defaults to 0.
  - -n <redis namespace>: A namespace separate pusher queues from others in redis. Defaults to pusher.
  - -l <logdir>: The directory where logfiles are stored. Defaults to $PWD/logs.
  - -p <piddir>: The directory where pid files are stored. Defaults to $PWD/pids.
  - -c <certs>: The directory where we temporarily store APN certs. Defaults to $PWD/certs.

The pusher daemon runs under the current user and current folder. If you specify the logid, piddir and certs folders make sure these exists and that the current user can create/write files inside those folder.

To start the server run:

```
/path/to/bin/pusher start -H localhost -P 6379 -b 0 -n pusher -p /var/run/pids
```

To stop the server run:

```
/path/to/bin/pusher start -H localhost -P 6379 -b 0 -n pusher -p /var/run/pids
```

If you set a piddir (using -p option) when starting the server then you must supply the same option when stopping or restarting the server.

The certs option (-c) is to temporarily store APN certificates. These are deleted when the APN connection is closed.

## Sending Notifications

Once the pusher daemon is running and connected to your redis server you can push notifications by publishing messages to redis. The message format is a simple JSON string.

### JSON string format

Example JSON message:

```
{
  'apn_ids': ["xxxxx"],
  'gcm_ids': ["xxxxx", "yyyyyy"],
  'development': true,
  'cert': "cert string",
  'api_key': "secret key",
  'time_to_live': 0,
  'data': {
    'aps': {
      'alert': "This is a message"
    }
  }
}
```

- apn_ids: This is an array with the list of iOS client tokens to which the push notification is to be sent. These are the tokens you get from the iOS devices when they register for APN push notifications.
- gcm_ids: This is an array with the list of Android client ids to which the push notification is to be sent. These IDs are obtained on the devices when they register for GCM push notifications. You may only have up to 1000 ids in this array.
- development: This can be true or false and indicates if the push notification is to be sent using the APN sandbox gateway (yes) or the APN production gateway (no). This option only affects push notifications to iOS devices and is assumed yes if not provided.
- cert: This is a string representation of the certificate used to send push notifications via the APN network. Simply read the cert.pem file as string and plug it in this field.
- api_key: This is the secret api_key used to send push notifications via the GCM network. This is the key you get from the Google API console.
- time_to_live: Time in seconds the message would be stored on the cloud in case the destination device is not available at the moment. The default value is zero that means the message is discarded if the destination is not reachable at the moment the notification is sent. Note that even if you set this value larger than zero there are limitations that may prevent the message from arriving. For example Google allows to store up to 4 sync messages or 100 payload messages for up to time_to_live messages or max 4 weeks while Apple only stores the last message up to to time_to_live seconds.
- data: This is a custom hash that is sent as push notification to the devices. For GCM this hash may contain anything you want as long as its size do not exceed 4096. For APN this data hash MUST contain an *aps* hash that follows Apple push notification format.

#### Apple *aps* hash

When sending push notifications to iOS devices you must provide an aps hash inside the data hash that follows the format:

"aps": {
  "alert": {
    "action-loc-key": "Open",
    "body": "Hello, world!"
  },
  "badge": 2,
  "sound": "default"
}

Read the [official documentation](http://developer.apple.com/library/ios/#documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/Chapters/ApplePushService.html#//apple_ref/doc/uid/TP40008194-CH100-SW1) for details on the *aps* hash format. Note that this hash must not exceed the 256 bytes or it will be rejected by the APN service.

#### Sending one message to both APN and GCM

Normally you would send messages to either Android or iOS indenpendently. But the pusher daemon can send the same message to devices on both networks as long as you follow the Apple restrictions. This is because Apple push messages are more limited than GCM.

If your data hash is compatible with the APN standard as described above and you specify a APN cert, a GCM api_key, a list of apn_ids and a list of gcm_ids then the message will be delivered via push notification to all the devices in those lists. Apple will display the notifications using their own mechanisms and for Android you will receive the data hash in a Bundle object as usual. Is your responsibility to extract the data from that bundle and display/use it as you please.

## Examples

A simple example using ruby code to send a push notification to iOS devices.

```ruby
require 'multi_json'
require 'redis'

# Build a message hash
msg = {
  apn_ids: ["xxxxx"],
  development: true,
  cert: File.read(pemfile),
  data: {
    aps: {
      alert: "This is a message"
    }
  }
}

# Format the hash as a JSON string. We use multi_json gem for this but you are free to use any JSON encoder you want.
msg_json = MultiJson.dump(msg)

# Obtain a redis instance
redis = Redis.new({ host: "localhost", port: 6379})

# Push the message to the *suj_pusher_queue* in the redis server:
redis.lpush "pusher:suj_pusher_msgs", msg_json

# Notify workers there is a new message
redis.publish "pusher:suj_pusher_queue", "PUSH_MSG"
```

First you must push your messages to the *suj_pusher_msgs* queue and then publish a *PUSH_MSG* to the *suj_pusher_queue*. The first is a simple queue that stores the messages and the second is a PUB/SUB queue that tells the push daemons that a new message is available. Also make sure to set the same namespace (e.g. pusher) to the queue names that you set on the pusher daemons.

## Issues

- We have no feedback mechanism. This is a fire and forget daemon that does not tell us if the message was sent or not.
- This daemon has no security at all. Anyone that can push to your redis server can use this daemon to spam your users. Make sure your redis server is only accessible to you and the pusher daemon.

## Troubleshooting

- You get errors like "Encryption not available on this event-machine", ensure that the eventmachine gem was installed with ssl support. If you are not sure uninstall the gem, install libssl-dev package and re-install the gem again.
- If you get 401 Unauthorized error on the log when sending notifications via GCM, ensure the key you use has configured the global IP addresses of the pusher daemons as allowed.

## TODO

- Implement a feedback mechanism that exposes a simple API to allow users check if some tokens, ids, certs, or api_keys are no longer valid so they can take proper action.
- Find a way to register certificates and api_key only once so we do not need to send them for every request. Maybe add a cert/key registration api.
