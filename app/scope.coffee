ko.mapper.handlers.callback = {
  fromJS: (value, options, target, wrap) ->
    unless target? 
      result = options.$create(value)
    else
      result = options.$update(value, target)
    return result

  toJS:(observable, options) -> observable.toJS()
}
ko.mapper.handlers.observe = ko.mapper.handlers.value


class DeviceAttribute 
  @mapping = {
    $default: 'ignore'
    description: "copy"
    label: "copy"
    labels: "copy"
    name: "copy"
    type: "copy"
    value: "observe"
    unit: 'copy'
    history: 'observe'
    lastUpdate: 'observe'
  }
  constructor: (data) ->
    #console.log "creating device attribute", data
    # Allways create an observable for value:
    unless data.value? then data.value = null
    @history = ko.observableArray([])
    ko.mapper.fromJS(data, @constructor.mapping, this)
    @valueText = ko.computed( =>
      value = @value()
      unless value?
        return __("unknown")
      if @type is 'boolean'
        unless @labels? then return value.toString()
        else if value is true then @labels[0] 
        else if value is false then @labels[1]
        else value.toString()
      else return value.toString()
    )
    @unitText = if @unit? then @unit else ''
    if @type is "number"
      @sparklineHistory = ko.computed( => ([t, v] for {t,v} in @history()) )

  showSparkline: -> @type is "number" and @history().length > 1

  showLastUpdate: -> 
    unless @type is "number" then return no
    now = (new Date()).getTime()
    lastUpdate = @lastUpdate()
    return (now-lastUpdate) > (1000*60*30) # older than 30min

  lastUpdateTimeText: ->
    return ' @ ' + @formatTime(@lastUpdate()).replace(' ', '<br>')

  tooltipFormatter: (sparkline, options, fields) => 
    value = @formatValue(fields.y)
    time = @formatTime(fields.x)
    return "<span>#{value} @ #{time}</span>"

  update: (data) -> 
    ko.mapper.fromJS(data, @constructor.mapping, this)

  updateValue: (timestamp, value) ->
    @value(value)
    @lastUpdate(timestamp)
    if @history().length is 30
      @history.shift()
    @history.push({t:timestamp, v:value})

  formatValue: (value) ->
    if @type is 'boolean'
      if @labels then (if value is true then @labels[0] else @labels[1])
      else value.toString()
    else
      if @unit? and @unit.length > 0 then "#{value} #{@unit}"
      else value

  formatTime: (time) -> 
    day = Highcharts.dateFormat('%Y-%m-%d', time)
    today = Highcharts.dateFormat('%Y-%m-%d', (new Date()).getTime())
    return(
      if day isnt today
        Highcharts.dateFormat('%Y-%m-%d %H:%M:%S', time)
      else
        Highcharts.dateFormat('%H:%M:%S', time)
    )

  toJS: () -> ko.mapper.toJS(this, @constructor.mapping)



class Device
  @mapping = {
    $default: 'ignore'
    name: 'observe'
    config: 'copy'
    configDefaults: 'copy'
    id: 'copy'
    name: 'observe'
    template: 'copy'
    actions: 'copy'
    attributes:
      $key: 'name'
      $itemOptions:
        $handler: 'callback'
        $create: (data) -> new DeviceAttribute(data)
        $update: (data, target) -> target.update(data); target

  }
  constructor: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)
    #@config = data.config
    @configObserve = ko.observable(data.config)
    @rest = {}
    for action in @actions
      pimatic.client.createRestAction(
        @rest,
        action.name,
        action,
        { type: "get", url: "/api/device/#{@id}/#{action.name}" }
      )
    @group = ko.computed( => 
      if @id is 'null' then return null
      pimatic.getGroupOfDevice(@id) 
    )

    @configWithDefaults = ko.computed( =>
      result = {}
      for name, c of @configDefaults
        result[name] = c
      for name, c of @configObserve()
        result[name] = c
      return result
    )

  update: (data) -> 
    ko.mapper.fromJS(data, @constructor.mapping, this)
    #@config = data.config if data.config?
    @configObserve(data.config)
  toJS: () -> ko.mapper.toJS(this, @constructor.mapping)

  getAttribute: (name) -> ko.utils.arrayFirst(@attributes(), (a) => a.name is name )
  updateAttribute: (attrName, timestamp, attrValue) ->
    attribute = @getAttribute(attrName)
    if attribute? then attribute.updateValue(timestamp, attrValue)

  hasAttibuteWith: (predicate) ->
    for attr in @attributes()
      if predicate(attr) then return yes
    return false

class Rule
  @mapping = {
    $default: 'ignore'
    id: 'copy'    
    name: 'observe'
    string: 'observe'   
    actionsToken: 'observe'
    conditionToken: 'observe'
    error: 'observe'
    active: 'observe'
    logging: 'observe'
    valid: 'observe'
  }
  constructor: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)
    @group = ko.computed( => pimatic.getGroupOfRule(@id) )
  update: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)
  toJS: () -> 
    ko.mapper.toJS(this, @constructor.mapping)

class Variable
  @mapping = {
    $default: 'ignore'
    exprInputStr: 'observe'
    exprTokens: 'observe'
    name: 'copy'
    readonly: 'observe'
    type: 'observe'
    value: 'observe'
  }
  constructor: (data) ->
    unless data.value? then data.value = null
    unless data.exprInputStr? then data.exprInputStr = null
    unless data.exprTokens? then data.exprTokens = null
    ko.mapper.fromJS(data, @constructor.mapping, this)
    @displayName = ko.computed( => "$#{@name}" )
    @hasValue = ko.computed( => @value()? )
    @displayValue = ko.computed( => if @hasValue() then @value() else "null" )
    @group = ko.computed( => pimatic.getGroupOfVariable(@name) )
  isDeviceAttribute: -> $.inArray('.', @name) isnt -1
  update: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)
  toJS: () -> ko.mapper.toJS(this, @constructor.mapping)

class DevicePage
  @mapping = {
    $default: 'ignore'
    id: 'copy'
    name: 'observe'
    devices:
      $key: 'deviceId'
      $itemOptions:
        $handler: 'callback'
        $create: (data) => 
          device = pimatic.getDeviceById(data.deviceId)
          unless device? 
            device = pimatic.nullDevice
          itemClass = pimatic.templateClasses[device.template]
          unless itemClass?
            console.warn "Could not find a template class for #{data.template}"
            itemClass = pimatic.DeviceItem
          unless device? then return console.error("Device should never be null")
          #console.log "Creating #{itemClass.name} for #{device.id} (#{device.template})"
          return new itemClass(data, device)
        $update: (data, target) -> target.update(data); target
  }

  constructor: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)

  getDevicesInGroup: (groupId) ->
    ds = (d for d in @devices() when (
        d.device.group()?.id is groupId and d.device isnt pimatic.nullDevice
      )
    )
    return ds 

  getUngroupedDevices: ->
    devices = @devices()
    ungrouped = (
      d for d in devices when (
        not d.device.group()? and d.device isnt pimatic.nullDevice
      )
    )
    return ungrouped

  update: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)
  getDeviceTemplate: (data) -> data.getDeviceTemplate()
  afterRenderDevice: (elements, item) ->
    item.afterRender(elements)
  toJS: () -> ko.mapper.toJS(this, @constructor.mapping)

class Group
  @mapping = {
    $default: 'ignore'
    id: 'copy'
    name: 'observe'
    rules: 'array'
    devices: 'array'
    variables: 'array'
  }
  constructor: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)
    @getDevices = ko.computed( =>
      devices = []
      for deviceId in @devices()
        deviceObj = pimatic.getDeviceById(deviceId)
        if deviceObj? then devices.push deviceObj
      return devices
    )
    @getRules = ko.computed( =>
      rules = []
      for ruleId in @rules()
        ruleObj = pimatic.getRuleById(ruleId)
        if ruleObj? then rules.push ruleObj
      return rules
    )
    @getVariables = ko.computed( =>
      variables = []
      for variableName in @variables()
        variableObj = pimatic.getVariableByName(variableName)
        if variableObj? then variables.push variableObj
      return variables
    )
  update: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)

  getDevicesWithAttibute: (predicate) ->
    return ( d for d in @getDevices() when d.hasAttibuteWith(predicate) )

  getDevicesWithNumericAttribute: ->
    return @getDevicesWithAttibute( (attr) => attr.type is "number" )

  containsDevice: (deviceId) ->
    index = ko.utils.arrayIndexOf(@devices(), deviceId)
    return (index isnt -1)
  toJS: () -> ko.mapper.toJS(this, @constructor.mapping)

class Pimatic
  @mapping = {
    $default: 'ignore'
    devices:
      $key: 'id'
      $itemOptions:
        $handler: 'callback'
        $create: (data) -> new Device(data)
        $update: (data, target) -> target.update(data); target
    rules:
      $key: 'id'
      $itemOptions:
        $handler: 'callback'
        $create: (data) -> new Rule(data)
        $update: (data, target) -> target.update(data); target
    variables:
      $key: 'name'
      $itemOptions:
        $handler: 'callback'
        $create: (data) -> new Variable(data)
        $update: (data, target) -> target.update(data); target
    devicepages:
      $key: 'id'
      $itemOptions:
        $handler: 'callback'
        $create: (data) -> new DevicePage(data)
        $update: (data, target) -> target.update(data); target
    groups:
        $key: 'id'
        $itemOptions:
          $handler: 'callback'
          $create: (data) -> new Group(data)
          $update: (data, target) -> target.update(data); target        

    errorCount: 'observe'
    rememberme: 'observe'
    updateProcessStatus: 'observe'
    updateProcessMessages: 'array'
    guiSettings: 'observe'
  }
  socket: null
  inited: no
  pages: {}
  storage: null
  _dataLoaded: ko.observable(no)

  nullDevice: new Device({
    id: 'null'
    name: 'null'
    attributes: []
    actions: []
    template: 'null'
  })

  constructor: () ->
    window.pimatic = this
    @client = new DeclApiClient(api)

    @updateFromJs({
      devices: []
      rules: []
      variables: []
      devicepages: []
      groups: []
      errorCount: 0
      rememberme: no
      updateProcessStatus: 'idle'
      updateProcessMessages: []
      guiSettings: null
    })
    @setupStorage()

    @updateProcessStatus.subscribe( (status) =>
      switch status
        when 'running'
          pimatic.loading "update-process-status", "show", {
            text: __('Installing updates, Please be patient')
          }
        else
          pimatic.loading "update-process-status", "hide"
    )

    @autosave = ko.computed( =>
      unless @_dataLoaded() then return
      data = @toJS()
      pimatic.storage.set('pimatic.scope', data)
    ).extend(rateLimit: {timeout: 500, method: "notifyWhenChangesStop"})

    sendToServer = yes
    @rememberme.subscribe( (shouldRememberMe) =>
      if sendToServer
        $.get("remember", rememberMe: shouldRememberMe)
          .done(ajaxShowToast)
          .fail( => 
            sendToServer = no
            @rememberme(not shouldRememberMe)
          ).fail(ajaxAlertFail)
      else 
        sendToServer = yes
      # swap storage
      allData = pimatic.storage.get('pimatic')
      pimatic.storage.removeAll()
      if shouldRememberMe
        pimatic.storage = $.localStorage
      else
        pimatic.storage = $.sessionStorage
      allData.scope.rememberMe = shouldRememberMe
      pimatic.storage.set('pimatic', allData)
    )

    @getUngroupedDevices = ko.computed( =>
      d for d in @devices() when not d.group()?
    )


  loadDataFromStorage: ->
    @_dataLoaded(yes)
    if pimatic.storage.isSet('pimatic.scope')
      data = pimatic.storage.get('pimatic.scope')
      try
        @updateFromJs(data)
      catch e
        TraceKit.report(e)
        pimatic.storage.removeAll()
        window.location.reload()


  updateFromJs: (data) -> ko.mapper.fromJS(data, Pimatic.mapping, this)

  toJS: -> ko.mapper.toJS(this, Pimatic.mapping)

  setupStorage: ->
    if $.localStorage.isSet('pimatic')
      # Select localStorage
      pimatic.storage = $.localStorage
      $.sessionStorage.removeAll()
      @rememberme(yes)
    else if $.sessionStorage.isSet('pimatic')
      # Select sessionSotrage
      pimatic.storage = $.sessionStorage
      $.localStorage.removeAll()
      @rememberme(no)
    else
      # select sessionStorage as default
      pimatic.storage = $.sessionStorage
      @rememberme(no)
      pimatic.storage.set('pimatic', {})

  # Device list
  getDeviceById: (id) -> 
    ko.utils.arrayFirst(@devices(), (d) => d.id is id )
  getGroupOfDevice: (deviceId) ->
    for g in @groups()
      index = ko.utils.arrayIndexOf(g.devices(), deviceId)
      if index isnt -1 then return g
    return null

  updateDeviceAttribute: (deviceId, attrName, time, attrValue) ->
    for device in @devices()
      if device.id is deviceId
        device.updateAttribute(attrName, time, attrValue)
        break
  updateDeviceFromJs: (deviceData) ->
    device = @getDeviceById(deviceData.id)
    unless device?
      device = Pimatic.mapping.devices.$itemOptions.$create(deviceData)
      @devices.push(device)
    else 
      device.update(deviceData)
  updateDeviceOrder: (order) ->
    toIndex = (id) -> 
      index = $.inArray(id, order)
      return (if index is -1 then 999999 else index)
    @devices.sort( (left, right) => toIndex(left.id) - toIndex(right.id) )
  removeDevice: (deviceId) ->
    @devices.remove( (d) => d.id is deviceId )

  # Devicepages
  getPageById: (id) -> 
    ko.utils.arrayFirst(@devicepages(), (p) => p.id is id )
  removePage: (pageId) ->
    @devicepages.remove( (p) => p.id is pageId )
  updatePageFromJs: (pageData) ->
    page = @getPageById(pageData.id)
    unless page?
      page = Pimatic.mapping.devicepages.$itemOptions.$create(pageData)
      @devicepages.push(page)
    else 
      page.update(pageData)
  updatePageOrder: (order) ->
    toIndex = (id) -> 
      index = $.inArray(id, order)
      return (if index is -1 then 999999 else index)
    @devicepages.sort( (left, right) => toIndex(left.id) - toIndex(right.id) )    

  # Groups
  getGroupById: (id) -> 
    ko.utils.arrayFirst(@groups(), (g) => g.id is id )
  removeGroup: (groupId) ->
    @groups.remove( (p) => p.id is groupId )
  updateGroupFromJs: (groupData) ->
    group = @getGroupById(groupData.id)
    unless group?
      group = Pimatic.mapping.groups.$itemOptions.$create(groupData)
      @groups.push(group)
    else 
      group.update(groupData)
  getGroupOfRule: (ruleId) ->
    for g in @groups()
      index = ko.utils.arrayIndexOf(g.rules(), ruleId)
      if index isnt -1 then return g
    return null
  updateGroupOrder: (order) ->
    toIndex = (id) -> 
      index = $.inArray(id, order)
      return (if index is -1 then 999999 else index)
    @groups.sort( (left, right) => toIndex(left.id) - toIndex(right.id) )    

  # Rules
  getRuleById: (id) -> 
    ko.utils.arrayFirst(@rules(), (r) => r.id is id )
  removeRule: (ruleId) ->
    @rules.remove( (rule) => rule.id is ruleId )
  updateRuleFromJs: (ruleData) ->
    rule = @getRuleById(ruleData.id)
    unless rule?
      rule = Pimatic.mapping.rules.$itemOptions.$create(ruleData)
      @rules.push(rule)
    else 
      rule.update(ruleData)
  updateRuleOrder: (order) ->
    toIndex = (id) -> 
      index = $.inArray(id, order)
      return (if index is -1 then 999999 else index)
    @rules.sort( (left, right) => toIndex(left.id) - toIndex(right.id) )

  # Variables
  removeVariable: (varName) ->
    @variables.remove( (variable) => variable.name is varName )
  getVariableByName: (name) -> 
    ko.utils.arrayFirst(@variables(), (v) => v.name is name )
  updateVariableValue: (name, value) ->
    variable = @getVariableByName(name)
    if variable?
      variable.value(value)
  updateVariableFromJs: (variableData) ->
    variable = @getVariableByName(variableData.name)
    unless variable?
      variable = Pimatic.mapping.variables.$itemOptions.$create(variableData)
      @variables.push(variable)
    else 
      variable.update(variableData)
  updateVariableOrder: (order) ->
    toIndex = (name) -> 
      index = $.inArray(name, order)
      return (if index is -1 then 999999 else index)
    @variables.sort( (left, right) => toIndex(left.name) - toIndex(right.name) )
  getGroupOfVariable: (variableName) ->
    for g in @groups()
      index = ko.utils.arrayIndexOf(g.variables(), variableName)
      if index isnt -1 then return g
    return null


window.pimatic = new Pimatic()
window.pimatic.Device = Device
window.pimatic.Rule = Rule
window.pimatic.Group = Group
window.pimatic.Variable = Variable
window.pimatic.DevicePage = DevicePage

$(document).on( "templateready", (event) ->
  # Just execute it one time
  if pimatic._dataLoaded() then return
  pimatic.loadDataFromStorage()
  return
)