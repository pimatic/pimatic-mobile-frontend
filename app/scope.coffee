class DeviceAttribute 
  @mapping = {
    observe: ["value"]
  }
  constructor: (data) ->
    #console.log "creating device attribute", data
    # Allways create an observable for value:
    unless data.value? then data.value = null
    ko.mapping.fromJS(data, @constructor.mapping, this)
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
  update: (data) -> 
    ko.mapping.fromJS(data, @constructor.mapping, this)

  formatValue: (value) ->
    if @type is 'boolean'
      if @labels then (if value is true then @labels[0] else @labels[1])
      else value.toString()
    else
      if @unit? and @unit.length > 0 then "#{value} #{@unit}"
      else value



class Device
  @mapping = {
    attributes:
      create: ({data, parent, skip}) => new DeviceAttribute(data)
      update: ({data, parent, target}) =>
        target.update(data)
        return target
      key: (data) => data.name
    observe: ["name", "attributes"]
    copy: ["config"]

  }
  constructor: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
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
    ko.mapping.fromJS(data, @constructor.mapping, this)
    #@config = data.config if data.config?
    @configObserve(data.config)

  getAttribute: (name) -> ko.utils.arrayFirst(@attributes(), (a) => a.name is name )
  updateAttribute: (attrName, attrValue) ->
    #console.log "updating", attrName, attrValue
    attribute = @getAttribute(attrName)
    if attribute?
      attribute.value(attrValue)

  hasAttibuteWith: (predicate) ->
    for attr in @attributes()
      if predicate(attr) then return yes
    return false

class Rule
  @mapping = {
    key: (data) => data.id
    copy: ['id']
  }
  constructor: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
    @group = ko.computed( => pimatic.getGroupOfRule(@id) )
  update: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)

class Variable
  @mapping = {
    key: (data) => data.name
    observe: ['value', 'type', 'exprInputStr', 'exprTokens']
  }
  constructor: (data) ->
    unless data.value? then data.value = null
    unless data.exprInputStr? then data.exprInputStr = null
    unless data.exprTokens? then data.exprTokens = null
    ko.mapping.fromJS(data, @constructor.mapping, this)
    @displayName = ko.computed( => "$#{@name}" )
    @hasValue = ko.computed( => @value()? )
    @displayValue = ko.computed( => if @hasValue() then @value() else "null" )
    @group = ko.computed( => pimatic.getGroupOfVariable(@name) )
  isDeviceAttribute: -> $.inArray('.', @name) isnt -1
  update: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)

class DevicePage
  @mapping = {
    key: (data) => data.id
    copy: ['id']
    devices:
      create: ({data, parent, skip}) => 
        device = pimatic.getDeviceById(data.deviceId)
        unless device? then device = pimatic.nullDevice
        itemClass = pimatic.templateClasses[device.template]
        unless itemClass?
          console.warn "Could not find a template class for #{data.template}"
          itemClass = pimatic.DeviceItem
        unless device? then return console.error("Device should never be null")
        #console.log "Creating #{itemClass.name} for #{device.id} (#{device.template})"
        return new itemClass(data, device)
      key: (data) => data.deviceId
  }
  constructor: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)

    @groupsWithDevices = ko.computed( =>
      return (
        for group in pimatic.groups()
          do (group) =>
            devices = ko.computed( => (d for d in @devices() when d.device.group() is group) )
            {group, devices} 
      )
    )

    @getUngroupedDevices = ko.computed( =>
      d for d in @devices() when not d.device.group()?
    )

    deepEqual = (a, b) ->
      if a.length isnt b.length then return false
      for e, i in a
        if e isnt b[i] then return false
      return true

  update: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
  getDeviceTemplate: (data) -> data.getDeviceTemplate()
  afterRenderDevice: (elements, item) ->
        item.afterRender(elements)

class Group
  @mapping = {
    key: (data) => data.id
    copy: ['id']
  }
  constructor: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
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
    ko.mapping.fromJS(data, @constructor.mapping, this)

  getDevicesWithAttibute: (predicate) ->
    return ( d for d in @getDevices() when d.hasAttibuteWith(predicate) )

  getDevicesWithNumericAttribute: ->
    return @getDevicesWithAttibute( (attr) => attr.type is "number" )

  containsDevice: (deviceId) ->
    index = ko.utils.arrayIndexOf(@devices(), deviceId)
    return (index isnt -1)

class Pimatic
  @mapping = {
    devices:
      create: ({data, parent, skip}) => new Device(data)
      update: ({data, parent, target}) =>
        target.update(data)
        return target
      key: (data) => data.id
    rules:
      create: ({data, parent, skip}) => new Rule(data)
      update: ({data, parent, target}) =>
        target.update(data)
        return target
      key: (data) => data.id
    variables:
      create: ({data, parent, skip}) => new Variable(data)
      update: ({data, parent, target}) =>
        target.update(data)
        return target
      key: (data) => data.name
    devicepages:
      create: ({data, parent, skip}) => new DevicePage(data)
      update: ({data, parent, target}) =>
        target.update(data)
        return target
      key: (data) => data.id
    groups:
      create: ({data, parent, skip}) => new Group(data)
      update: ({data, parent, target}) =>
        target.update(data)
        return target
      key: (data) => data.id
  }
  socket: null
  inited: no
  pages: {}
  storage: null

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
      data = ko.mapping.toJS(this)
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
    @_dataLoaded = yes
    if pimatic.storage.isSet('pimatic.scope')
      data = pimatic.storage.get('pimatic.scope')
      try
        @updateFromJs(data)
      catch e
        TraceKit.report(e)
        pimatic.storage.removeAll()
        window.location.reload()


  updateFromJs: (data) ->
    ko.mapping.fromJS(data, Pimatic.mapping, this)

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

  updateDeviceAttribute: (deviceId, attrName, attrValue) ->
    for device in @devices()
      if device.id is deviceId
        device.updateAttribute(attrName, attrValue)
        break
  updateDeviceFromJs: (deviceData) ->
    device = @getDeviceById(deviceData.id)
    unless device?
      device = Pimatic.mapping.devices.create({data: deviceData})
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
      page = Pimatic.mapping.devicepages.create({data: pageData})
      @devicepages.push(page)
    else 
      page.update(pageData)

  # Groups
  getGroupById: (id) -> 
    ko.utils.arrayFirst(@groups(), (g) => g.id is id )
  removeGroup: (groupId) ->
    @groups.remove( (p) => p.id is groupId )
  updateGroupFromJs: (groupData) ->
    group = @getGroupById(groupData.id)
    unless group?
      group = Pimatic.mapping.groups.create({data: groupData})
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
      rule = Pimatic.mapping.rules.create({data: ruleData})
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
      variable = Pimatic.mapping.variables.create({data: variableData})
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

$(document).on( "pagebeforecreate", (event) ->
  # Just execute it one time
  if pimatic._dataLoaded then return
  pimatic.loadDataFromStorage()
  return
)