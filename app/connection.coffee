
$(document).on( "pagebeforecreate", (event) ->
  # Just execte this function one time:
  if pimatic.socket? then return

  pimatic.client = new DeclApiClient(api)

  pimatic.socket = io('/',{
    reconnection: yes
    reconnectionDelay: 1000
    reconnectionDelayMax: 3000
    timeout: 20000
  })

  pimatic.socket.io.on 'open', (socket) ->
    #console.log "m: open"
    pimatic.loading "socket", "hide"

    if window.applicationCache?
      try
        window.applicationCache.update()
      catch e
        console.log e


  pimatic.socket.on('devices', (devices) -> pimatic.updateFromJs({devices}) )
  pimatic.socket.on('rules', (rules) -> pimatic.updateFromJs({rules}) )
  pimatic.socket.on('variables', (variables) -> pimatic.updateFromJs({variables}) )
  pimatic.socket.on('pages', (pages) -> pimatic.updateFromJs({devicepages: pages}) )
  #pimatic.socket.io.on 'close', -> console.log "m: close"

  pimatic.socket.io.on('reconnect_attempt', -> 
    #console.log "m: reconnect attemp"
    pimatic.loading("socket", "show", {
      text: __("connection lost, retrying")
      blocking: no
    })
  )

  pimatic.socket.io.on('connect_error', (error) -> 
    #console.log "m: connect_error", error
    pimatic.loading("socket", "show", {
      text: __("could not connect (%s), retrying", error.message)
      blocking: no
    })
  )

  pimatic.socket.io.on('connect_timeout', -> 
    #console.log "m: connect_timeout"
    pimatic.loading("socket", "show", {
      text: __("connect timed out")
      blocking: no
    })
  )


)
