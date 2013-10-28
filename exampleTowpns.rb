require 'multi_json'
require 'redis'
require 'cgi'
# Build a message hash
#badge = '<badge value="52"/>'
badge = '<badge value="alarm"/>'
#badge = '<badge value="attention"/>'

toast3 = '<?xml version="1.0" encoding="utf-8"?><wp:Notification xmlns:wp="WPNotification"><wp:Toast><wp:Text1>Text prueba</wp:Text1><wp:Text2>Texto prueba 2</wp:Text2></wp:Toast></wp:Notification>'
raw = 'asd'

# Format the hash as a JSON string. We use multi_json gem for this but you are free to use any JSON encoder you want.
msg = {  wptype: "toast",  wpids: ["http://dm2.notify.live.net/throttledthirdparty/01.00/AQHgQ4jFCjRMSanN0SpURO3QAgAAAAADng0DAAQUZm52OkJCMjg1QTg1QkZDMkUxREQFBkxFR0FDWQ"]  , secret: "CWOl6UQYOfica3kl8r0s0CjP9+wE2pgu", development: false, wpnotificationclass: 2, data: toast3}
msg_json = MultiJson.dump(msg)
puts msg_json

# Obtain a redis instance
redis = Redis.new({ host: "localhost", port: 6379})

# Push the message to the *suj_pusher_queue* in the redis server:
redis.lpush "pusher:suj_pusher_msgs", msg_json

# Notify workers there is a new message
redis.publish "pusher:suj_pusher_queue", "PUSH_MSG"
