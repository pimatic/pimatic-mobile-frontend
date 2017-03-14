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


setupUnitPrefixes = ( ->

  siPrefixes = humanFormat.makePrefixes(
    'y,z,a,f,p,n,µ,m,,k,M,G,T,P,E,Z,Y'.split(','),
    1e3, # Base.
    -8   # Exponent for the first value.
  )

  wPrefixes = humanFormat.makePrefixes(
    ',k'.split(','),
    1e3, # Base.
    0   # Exponent for the first value.
  )

  mPrefixes = humanFormat.makePrefixes(
    'm,c,d,'.split(','),
    10, # Base.
    -3   # Exponent for the first value.
  )

  humanFormat.unitPrefixes = {
    'B': siPrefixes,
    'W': wPrefixes,
    'Wh': wPrefixes,
    'm': mPrefixes
  }
)()

class DeviceAttribute 
  @mapping = {
    $default: 'ignore'
    description: "copy"
    label: "copy"
    acronym: "copy"
    labels: "copy"
    name: "copy"
    type: "copy"
    value: "observe"
    unit: 'copy'
    history: 'observe'
    lastUpdate: 'observe'
    displaySparkline: 'observe'
    displayUnit: 'copy'
    discrete: 'copy'
    icon: 'copy'
    hidden: 'copy'
  }
  constructor: (data, @device) ->
    #console.log "creating device attribute", data
    # Allways create an observable for value:
    unless data.value? then data.value = null

    @history = ko.observableArray([])
    @lastUpdate = ko.observable(0)
    
    ko.mapper.fromJS(data, @constructor.mapping, this)

    @unitText = if @unit? then @unit else ''
    if @type is "number"
      @sparklineHistory = ko.pureComputed( => ([t, v] for {t,v} in @history()) )

  shouldDisplaySparkline: -> 
    return (
      @type is "number" and 
      @history().length > 1 and 
      (if @displaySparkline? and @displaySparkline()? then @displaySparkline() else true)
    )

  tooltipHtml: => 
    @label + ': ' +
    @formatValue(@value()) + 
    ' ' + @lastUpdateTimeText() + 
    (if @type in ["number", "boolean"] then """
      <a href="#" id="to-graph-page"
        data-attributeName="#{@name}"
        data-deviceId="#{@device.id}">#{__('Graph')}</a>
    """ else '') + """
    <a href="#" id="to-device-editor-page"
    data-deviceId="#{@device.id}">#{__('Edit Device')}</a>
    """

  outOfDate: -> 
    unless @type is "number" then return no
    now = (new Date()).getTime()
    lastUpdate = @lastUpdate()
    return (now-lastUpdate) > (1000*60*30) # older than 30min

  lastUpdateTimeText: ->
    return ' @ ' + @formatTime(@lastUpdate())

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

  displayValueText: ->
    value = @value()
    unless value?
      return __("unknown")
    if @type is 'number'
      format = @_getNumberFormat(value)
      return format.num
    else
      return @formatValue(value)

  displayUnitText: ->
    if @type is 'number'
      value = @value()
      format = @_getNumberFormat(value)
      return format.unit
    else
      return ''

  shouldDisplayAcronym: -> @acronym?.length > 0

  displayAcronym: ->
    return @acronym or ''

  formatValue: (value) ->
    switch @type
      when 'boolean'
        if @labels then (if value is true then __(@labels[0]) else __(@labels[1]))
        else value.toString()
      when 'string' then value
      when "number"
        format = @_getNumberFormat(value)
        "#{format.num} #{format.unit}"
      else
        value.toString()

  _getNumberFormat: (value) ->
    if @unit in Object.keys(humanFormat.unitPrefixes)
      if @displayUnit? and @unit?
        prefix = @displayUnit.substring(0, @displayUnit.length - @unit.length)
      else
        prefix = null
      info = humanFormat.humanFormatInfo(value, {
        unit: @unit
        prefixes: humanFormat.unitPrefixes[@unit]
        prefix
      })
      # show 3 decimals for kW and kWh
      if info.unit in ['W', 'Wh'] and info.prefix is 'k'
        info.num = Math.round(value) / 1e3
        info.num = info.num.toFixed(3)
      # show > 1000m as km
      else if info.unit is "m" and info.prefix is ""
        if value >= 1000
          info.num = Math.round(value / 100) / 10
          info.prefix = 'k'
      return {
        num: info.num
        unit: info.prefix + info.unit
      }
    else
      if @unit in ['kW', 'kWh']
        num = Math.round(value * 1e3) / 1e3
        num = num.toFixed(3)
      # handle seconds
      else if @unit is "s"
        num = pimatic.toHHMMSS(value)
        return {num, unit: ''}
      else
        num = Math.round(value * 1e2) / 1e2
      return {
        num
        unit: @unit or ''
      }

  shouldDisplayValue: ->
    if @icon?.noText then return false
    else return true

  shouldDisplayIcon: -> @icon? and @value()?

  _getIconClass: (value) ->
    unless @icon? then return null
    iconClass = null
    if @icon.mapping?
      for ico, val of @icon.mapping
        if $.isArray(val) and val.length is 2 # range given
          if val[0] <= value < val[1]
            iconClass = ico
            break
        else if val is value
          iconClass = ico
          break
    iconClass = @icon.default unless iconClass?
    return iconClass

  getIconClass: -> @_getIconClass(@value())

  formatTime: (time) -> 
    dt = pimatic.timestampToDateTime(time)
    today = pimatic.timestampToDateTime(new Date())
    return(
      if dt.date isnt today.date then "#{dt.date} #{dt.time}" else dt.time
    )

  toJS: () -> ko.mapper.toJS(this, @constructor.mapping)


class Device
  @mapping = {
    $default: 'ignore'
    name: 'observe'
    config: 'copy'
    configDefaults: 'copy'
    id: 'copy'
    template: 'copy'
    actions: 'copy'
    attributes:
      $key: 'name'
      $itemOptions:
        $handler: 'callback'
        $create: (data) -> new DeviceAttribute(data, Device.mapping.device)
        $update: (data, target) -> target.update(data); target

  }
  constructor: (data) ->
    Device.mapping.device = this
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
    @group = ko.pureComputed( => 
      if @id is 'null' then return null
      pimatic.getGroupOfDevice(@id) 
    )

    @configWithDefaults = ko.pureComputed( =>
      result = {}
      for name, c of @configDefaults
        result[name] = c
      for name, c of @configObserve()
        result[name] = c
      return result
    )

  update: (data) -> 
    Device.mapping.device = this
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
    @group = ko.pureComputed( => pimatic.getGroupOfRule(@id) )
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
    unit: 'observe'
  }
  constructor: (data) ->
    unless data.value? then data.value = null
    unless data.exprInputStr? then data.exprInputStr = null
    unless data.exprTokens? then data.exprTokens = null
    ko.mapper.fromJS(data, @constructor.mapping, this)
    @displayName = ko.pureComputed( => "$#{@name}" )
    @hasValue = ko.pureComputed( => @value()? )
    @displayValue = ko.pureComputed( => if @hasValue() then @value() else "null" )
    @group = ko.pureComputed( => pimatic.getGroupOfVariable(@name) )
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
            console.warn "Could not find a template class for #{device.template}"
            itemClass = pimatic.DeviceItem
          unless device? then return console.error("Device should never be null")
          #console.log "Creating #{itemClass.name} for #{device.id} (#{device.template})"
          return new itemClass(data, device)
        $update: (data, target) -> target.update(data); target
  }

  constructor: (data) ->
    ko.mapper.fromJS(data, @constructor.mapping, this)

    @deviceByGroups = ko.pureComputed( =>
      mapping = {
        '$ungrouped': []
      }
      for d in @devices()
        if d.device isnt pimatic.nullDevice
          g = pimatic.getGroupOfDevice(d.device.id)
          groupId = g?.id or '$ungrouped'
          if mapping[groupId]?
            mapping[groupId].push d
          else
            mapping[groupId] = [d]
      return mapping
    )


  getDevicesInGroup: (groupId) ->
    return @deviceByGroups()[groupId] or []

  getUngroupedDevices: ->
    return @deviceByGroups()['$ungrouped']

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
    @getDevices = ko.pureComputed( =>
      devices = []
      for deviceId in @devices()
        deviceObj = pimatic.getDeviceById(deviceId)
        if deviceObj? then devices.push deviceObj
      return devices
    )
    @getRules = ko.pureComputed( =>
      rules = []
      for ruleId in @rules()
        ruleObj = pimatic.getRuleById(ruleId)
        if ruleObj? then rules.push ruleObj
      return rules
    )
    @getVariables = ko.pureComputed( =>
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

  getDevicesWithGraphableAttribute: ->
    return @getDevicesWithAttibute( (attr) => attr.type in ["number", "boolean"] )

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
    username: 'observe'
    role: 'observe'
    permissions: 'observe'
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
      username: null
      role: null
      permissions: [
        pages: "none",
        rules: "none",
        variables: "none",
        messages: "none",
        events: "none",
        devices: "none",
        groups: "none",
        plugins: "none",
        updates: "none"
      ]
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

    @rememberme.subscribe( (shouldRememberMe) =>
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

    @getUngroupedDevices = ko.pureComputed( =>
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

  hasPermission: (scope, access) =>
    permissions = @permissions()[scope]
    switch access
      when 'read' then (permissions is "read" or permissions is "write")
      when 'write' then (permissions is "write")
      else no

  isDemo: => @guiSettings()?.demo

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