
$(document).on( "pagebeforecreate", (event) ->
  # Just execte this function one time:
  if pimatic.socket? then return

  pimatic.socket = io.connect("/", 
    'connect timeout': 20000
    'reconnection delay': 500
    'reconnection limit': 2000 # the max delay
    'max reconnection attempts': Infinity
  )

  pimatic.socket.on 'connect', ->
    pimatic.loading "socket", "hide"
    if window.applicationCache?
      try
        window.applicationCache.update()
      catch e
        console.log e

  pimatic.socket.on 'connecting', ->
    pimatic.loading "socket", "show",
      text: __("connecting")
      blocking: (not pimatic.pages.index.hasData)

  pimatic.socket.on 'disconnect', ->
    pimatic.loading "socket", "show",
      text: __("connection lost, retrying")
      blocking: (not pimatic.pages.index.hasData)

  onConnectionError = (reason) ->
    if reason is 'handshake unauthorized'
      # wrap inside setTimeout because stange iphone behavior
      # https://github.com/pimatic/pimatic/issues/69 
      setTimeout(pimatic.pages.index.toLoginPage, 10)
    if reason? and reason.length isnt 0 then reason = ": #{reason}"
    else reason = ''
    pimatic.loading "socket", "show",
      text: __("could not connect%s, retrying", reason)
      blocking: (not pimatic.pages.index.hasData)
    setTimeout ->
      pimatic.socket.socket.connect()
    , 2000

  pimatic.socket.on 'error', onConnectionError
  pimatic.socket.on 'connect_error', onConnectionError
  return
)
