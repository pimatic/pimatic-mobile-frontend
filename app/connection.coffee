tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", (event) ->
  # Just execte this function one time:
  if pimatic.socket? then return

  pimatic.socket = io('/',{
    reconnection: yes
    reconnectionDelay: 1000
    reconnectionDelayMax: 3000
    timeout: 20000
  })

  pimatic.socket.io.on 'open', () ->
    #console.log "m: open"
    pimatic.loading "socket", "hide"

    if window.applicationCache?
      try
        window.applicationCache.update()
      catch e
        console.log e

  pimatic.socket.on('connect', ->
    pimatic.socket.emit('call', {
      id: 'errorMessageCount'
      action: 'queryMessagesCount'
      params:
        criteria:
          level: 'error'
    })

    pimatic.socket.emit('call', {
      id: 'guiSettings'
      action: 'getGuiSetttings'
      params: {}
    })

    pimatic.socket.emit('call', {
      id: 'updateProcessStatus'
      action: 'getUpdateProcessStatus'
      params: {}
    })

  )

  pimatic.socket.on('callResult', (msg) ->
    switch msg.id
      when 'errorMessageCount'
        if msg.success
          pimatic.errorCount(msg.result.count)
      when 'guiSettings'
        if msg.success
          guiSettings = msg.result.guiSettings
          for k, v of guiSettings.defaults
            unless guiSettings.config[k]?
              guiSettings.config[k] = v
          pimatic.guiSettings(guiSettings.config)
      when 'updateProcessStatus'
        info = msg.result.info
        pimatic.updateProcessStatus(info.status)
        pimatic.updateProcessMessages(info.messages)
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
  pimatic.socket.on('groups', tc (groups) -> 
    pimatic.updateFromJs({groups}) 
  )
  pimatic.socket.on("deviceAttributeChanged", (attrEvent) -> 
    pimatic.updateDeviceAttribute(
      attrEvent.deviceId, 
      attrEvent.attributeName, 
      attrEvent.time,
      attrEvent.value
    )
  )
  pimatic.socket.on("deviceOrderChanged", tc (order) -> 
    pimatic.updateDeviceOrder(order)
  )

  pimatic.socket.on("deviceChanged", tc (device) ->
    pimatic.updateDeviceFromJs(device)
  )
  pimatic.socket.on("deviceRemoved", tc (device) -> 
    pimatic.removeDevice(device.id)
  )
  pimatic.socket.on("deviceAdded", tc (device) -> 
    pimatic.updateDeviceFromJs(device)
  )


  pimatic.socket.on("pageChanged", tc (page) ->
    pimatic.updatePageFromJs(page)
  )
  pimatic.socket.on("pageRemoved", tc (page) -> 
    pimatic.removePage(page.id)
  )
  pimatic.socket.on("pageAdded", tc (page) -> 
    pimatic.updatePageFromJs(page)
  )
  pimatic.socket.on("pageOrderChanged", tc (order) -> 
    pimatic.updatePageOrder(order)
  )


  pimatic.socket.on("groupChanged", tc (group) ->
    pimatic.updateGroupFromJs(group)
  )
  pimatic.socket.on("groupRemoved", tc (group) -> 
    pimatic.removeGroup(group.id)
  )
  pimatic.socket.on("groupAdded", tc (group) -> 
    pimatic.updateGroupFromJs(group)
  )
  pimatic.socket.on("groupOrderChanged", tc (order) -> 
    pimatic.updateGroupOrder(order)
  )


  pimatic.socket.on("ruleAdded", tc (rule) -> 
    pimatic.updateRuleFromJs(rule)
  )
  pimatic.socket.on("ruleChanged", tc (rule) -> 
    pimatic.updateRuleFromJs(rule)
  )
  pimatic.socket.on("ruleRemoved", tc (rule) -> 
    pimatic.removeRule(rule.id)
  )
  pimatic.socket.on("ruleOrderChanged", tc (order) -> 
    pimatic.updateRuleOrder(order)
  )

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
  pimatic.socket.on("variableOrderChanged", tc (order) -> 
    pimatic.updateVariableOrder(order)
  )

  pimatic.socket.on("updateProcessStatus", tc (statusEvent) -> 
    pimatic.updateProcessStatus(statusEvent.status)
  )
  pimatic.socket.on("updateProcessMessage", tc (msgEvent) -> 
    console.log msgEvent
    pimatic.updateProcessMessages.push(msgEvent.message)
  )
  
  pimatic.socket.on('messageLogged', tc (entry) -> 
    if entry.level isnt "debug" then pimatic.try => pimatic.showToast entry.msg
    if entry.level is "error" then pimatic.errorCount(pimatic.errorCount()+1)
  )

  # pimatic.socket.on('connect', ->
  #   pimatic.socket.emit('call', {
  #     action: 'getDevices'
  #     params: []
  #     id: 0
  #   })
  #   pimatic.socket.on('callResult', (result) =>
  #     console.log result
  #   )
  # )

  #pimatic.socket.io.on 'close', -> console.log "m: close"
  pimatic.loading("socket", "show", {
    text: __("Connecting")
    blocking: no
  })

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
