  
pimatic.socket = io.connect("/", 
  'connect timeout': 20000
  'reconnection delay': 500
  'reconnection limit': 2000 # the max delay
  'max reconnection attempts': Infinity
)

pimatic.socket.on 'log', (entry) -> 
  if entry.level is 'error' 
    pimatic.errorCount++
    updateErrorCount()
  showToast entry.msg
  console.log entry

pimatic.socket.on 'reconnect', ->
  $.mobile.loading "hide"
  loadData()
  if window.applicationCache?
    window.applicationCache.update()

pimatic.socket.on 'disconnect', ->
 $.mobile.loading "show",
  text: __("connection lost, retying")+'...'
  textVisible: true
  textonly: false

onConnectionError = ->
  $.mobile.loading "show",
    text: __("could not connect, retying")+'...'
    textVisible: true
    textonly: false
  setTimeout ->
    pimatic.socket.socket.connect( ->
      $.mobile.loading "hide"
      loadData()
      if window.applicationCache?
        window.applicationCache.update()
    )
  , 2000



    
pimatic.socket.on 'error', onConnectionError
pimatic.socket.on 'connect_error', onConnectionError