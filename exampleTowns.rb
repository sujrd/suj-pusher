require 'multi_json'
require 'redis'
require 'cgi'
# Build a message hash
#badge = '<badge value="52"/>'
badge = '<badge value="alarm"/>'
#badge = '<badge value="attention"/>'

raw = "asdfwesd"
tile = '<tile><visual><binding template="TileSquarePeekImageAndText04"><image id="1" src="http://www.radiodelmar.cl/rdm_2012/images/stories/logos/Falabella.jpg" alt="alt text"/> <text id="1">hola</text></binding></visual> </tile>'
toast = '<toast> <visual> <binding template="ToastImageAndText02"> <image id="1" src="http://www.radiodelmar.cl/rdm_2012/images/stories/logos/Falabella.jpg" alt="Falabella"> </image> <text id="1"> HOLA!!! </text> <text id="2"> Este es el super texto de la notificacion </text> </binding> </visual> </toast>'
msg = { wnstype: "wns/toast" , wnsrequeststatus: true, wnsids: ["https://bn1.notify.windows.com/?token=AgYAAAB9I4fa8UTUmmFrpcEouig6hZT%2bPvayhsiaymx5Oia%2f1ze86xFhU%2bp4CcNq6x5jV5flPAcYsKWUMl%2fKHS8Yx39Re3AqkYVXCEj2d%2bgLmbkTmISe1JZQy7lnIgy2F0OJF%2fI%3d"]  , secret: "CWOl6UQYOfica3kl8r0s0CjP9+wE2pgu", development: false, sid: "ms-app://s-1-15-2-3829771517-138112879-2919921299-1712475657-3425031058-1104050768-387431532", data: toast}
#msg = { wnstype: "wns/tile" , wnsrequeststatus: true, wnsids: ["https://bn1.notify.windows.com/?token=AgYAAAB9I4fa8UTUmmFrpcEouig6hZT%2bPvayhsiaymx5Oia%2f1ze86xFhU%2bp4CcNq6x5jV5flPAcYsKWUMl%2fKHS8Yx39Re3AqkYVXCEj2d%2bgLmbkTmISe1JZQy7lnIgy2F0OJF%2fI%3d"]  , secret: "CWOl6UQYOfica3kl8r0s0CjP9+wE2pgu", development: false, sid: "ms-app://s-1-15-2-3829771517-138112879-2919921299-1712475657-3425031058-1104050768-387431532", data: tile}
#msg = { wnstype: "wns/raw" , wnsrequeststatus: true, wnsids: ["https://bn1.notify.windows.com/?token=AgYAAAB9I4fa8UTUmmFrpcEouig6hZT%2bPvayhsiaymx5Oia%2f1ze86xFhU%2bp4CcNq6x5jV5flPAcYsKWUMl%2fKHS8Yx39Re3AqkYVXCEj2d%2bgLmbkTmISe1JZQy7lnIgy2F0OJF%2fI%3d"]  , secret: "CWOl6UQYOfica3kl8r0s0CjP9+wE2pgu", development: false, sid: "ms-app://s-1-15-2-3829771517-138112879-2919921299-1712475657-3425031058-1104050768-387431532", data: raw}
#msg = { wnstype: "wns/badge" , wnsrequeststatus: true, wnsids: ["https://bn1.notify.windows.com/?token=AgYAAAB9I4fa8UTUmmFrpcEouig6hZT%2bPvayhsiaymx5Oia%2f1ze86xFhU%2bp4CcNq6x5jV5flPAcYsKWUMl%2fKHS8Yx39Re3AqkYVXCEj2d%2bgLmbkTmISe1JZQy7lnIgy2F0OJF%2fI%3d"]  , secret: "CWOl6UQYOfica3kl8r0s0CjP9+wE2pgu", development: false, sid: "ms-app://s-1-15-2-3829771517-138112879-2919921299-1712475657-3425031058-1104050768-387431532", data: badge}
# Format the hash as a JSON string. We use multi_json gem for this but you are free to use any JSON encoder you want.
msg_json = MultiJson.dump(msg)
puts msg_json

# Obtain a redis instance
redis = Redis.new({ host: "localhost", port: 6379})

# Push the message to the *suj_pusher_queue* in the redis server:
redis.lpush "pusher:suj_pusher_msgs", msg_json

# Notify workers there is a new message
redis.publish "pusher:suj_pusher_queue", "PUSH_MSG"
