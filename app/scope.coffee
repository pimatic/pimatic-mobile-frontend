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

class Device
  @mapping = {
    attributes:
      create: ({data, parent, skip}) => new DeviceAttribute(data)
      update: ({data, parent, target}) =>
        target.update(data)
        return target
      key: (data) => data.name
    observe: ["name", "attributes"]
  }
  constructor: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
  update: (data) -> 
    ko.mapping.fromJS(data, @constructor.mapping, this)
  getAttribute: (name) -> ko.utils.arrayFirst(@attributes(), (a) => a.name is name )
  updateAttribute: (attrName, attrValue) ->
    #console.log "updating", attrName, attrValue
    attribute = @getAttribute(attrName)
    if attribute?
      attribute.value(attrValue)

class Rule
  @mapping = {
    key: (data) => data.id
    copy: ['id']
  }
  constructor: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
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
      key: (data) => data.name
  }
  constructor: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
    @isActive = ko.computed( =>
      return(
        unless pimatic.pages.index? then no
        else pimatic.pages.index.activeDevicepage() is @
      )
    )
  update: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
  getDeviceTemplate: (data) -> data.getDeviceTemplate()
  afterRenderDevice: (elements, item) ->
        item.afterRender(elements)


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
  }
  socket: null
  inited: no
  pages: {}
  storage: null

  nullDevice: new Device({
    id: 'null'
    name: 'null'
    attributes: []
    template: 'null'
  })

  constructor: (data) -> 
    @updateFromJs(data)
  updateFromJs: (data) ->
    ko.mapping.fromJS(data, Pimatic.mapping, this)

  # Device list
  getDeviceById: (id) -> 
    ko.utils.arrayFirst(@devices(), (d) => d.id is id )
  updateDeviceAttribute: (deviceId, attrName, attrValue) ->
    for device in @devices()
      if device.id is deviceId
        device.updateAttribute(attrName, attrValue)
        break

  # Devicepages
  updatePageFromJs: (pageData) ->
    for page in @devicepages()
      if page.id is pageData.id
        page.update(pageData)
        break
  getPageById: (id) -> 
    ko.utils.arrayFirst(@devicepages(), (d) => d.id is id )
  removePage: (pageId) ->
    @devicepages.remove( (p) => p.id is pageId )
  updatePageFromJs: (pageData) ->
    page = @getPageById(pageData.id)
    unless page?
      page = Pimatic.mapping.devicepages.create({data: pageData})
      @devicepages.push(page)
    else 
      page.update(pageData)

  # Rules
  getRuleById: (id) -> 
    ko.utils.arrayFirst(@rules(), (r) => r.id is id )
  removeRule: (ruleId) ->
    @rules.remove( (rule) => rule.id is ruleId )
  updateRuleFromJs: (ruleData) ->
    rule = @getRuleById(ruleData.id)
    unless rule?
      rule = Pimatic.mapping.devicerules.create({data: ruleData})
      @devicerules.push(rule)
    else 
      rule.update(ruleData)

  # Variables
  removeVariable: (varName) ->
    @variables.remove( (variable) => variable.name is varName )
  getVariableByName: (name) -> 
    ko.utils.arrayFirst(@variables(), (v) => v.name is name )
  updateVariableFromJs: (variableData) ->
    variable = @getVariableById(variableData.name)
    unless variable?
      variable = Pimatic.mapping.devicevariables.create({data: variableData})
      @devicevariables.push(variable)
    else 
      variable.update(variableData)

window.pimatic = new Pimatic({devices: [], rules: [], variables: [], devicepages: []})