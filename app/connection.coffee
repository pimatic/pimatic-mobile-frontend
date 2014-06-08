tc = pimatic.tryCatch

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

  pimatic.socket.on('message', tc (data) ->
    console.log data
  )

  pimatic.socket.on('devices', tc (devices) -> 
    pimatic.updateFromJs({devices})
  )
  pimatic.socket.on('rules', tc (rules) -> 
    pimatic.updateFromJs({rules}) 
  )
  pimatic.socket.on('variables', tc (variables) -> 
    pimatic.updateFromJs({variables}) 
  )
  pimatic.socket.on('pages', tc (pages) -> 
    pimatic.updateFromJs({devicepages: pages}) 
  )
  pimatic.socket.on("deviceAttributeChanged", (attrEvent) -> 
    pimatic.updateDeviceAttribute(
      attrEvent.deviceId, 
      attrEvent.attributeName, 
      attrEvent.value
    )
  )
  pimatic.socket.on("pageChanged", tc (page) ->
    pimatic.updatePageFromJs(page)
  )
  pimatic.socket.on("pageRemoved", tc (page) -> 
    pimatic.removePage(page.id)
  )
  pimatic.socket.on("pageAdded", tc (page) -> 
    pimatic.addPage(page.id)
  )
  #pimatic.socket.on("item-order", tc (order) -> indexPage.updateItemOrder(order))
  pimatic.socket.on("ruleAdded", tc (rule) -> 
    pimatic.updateRuleFromJs(rule)
  )
  pimatic.socket.on("ruleChanged", tc (rule) -> 
    pimatic.updateRuleFromJs(rule)
  )
  pimatic.socket.on("ruleRemoved", tc (rule) -> 
    pimatic.removeRule(rule.id)
  )
  #pimatic.socket.on("rule-order", tc (order) -> indexPage.updateRuleOrder(order))

  pimatic.socket.on("variableAdded", tc (variable) -> 
    pimatic.updateVariableFromJs(variable)
  )
  pimatic.socket.on("variableChanged", tc (variable) -> 
    pimatic.updateVariableFromJs(variable)
  )
  pimatic.socket.on("variableValueChanged", tc (varValEvent) -> 
    pimatic.updateVariableValue(varValEvent.variableName, varValEvent.variableValue)
  )
  pimatic.socket.on("variableRemoved", tc (variable) -> 
    pimatic.removeVariable(variable.name)
  )
  #pimatic.socket.on("variable-order", tc (order) -> indexPage.updateVariableOrder(order))

  pimatic.socket.on("updateProcessStatus", tc (statusEvent) -> 
    pimatic.updateProcessStatus(statusEvent.status)
  )
  pimatic.socket.on("updateProcessMessage", tc (msgEvent) -> 
    pimatic.updateProcessMessages.push(msgEvent.message)
  )
  
  pimatic.socket.on('messageLogged', tc (entry) -> 
    if entry.level isnt "debug" then pimatic.try => pimatic.showToast entry.msg
  )

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
