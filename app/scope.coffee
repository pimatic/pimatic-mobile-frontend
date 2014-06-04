class DeviceAttribute 
  @mapping = {
    observe: ["value"]
  }
  constructor: (data) ->
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

class Device
  @mapping = {
    attributes:
      create: ({data, parent, skip}) => new DeviceAttribute(data)
      key: (data) => data.name
    observe: ["name", "attributes"]
  }
  constructor: (data) ->
    ko.mapping.fromJS(data, @constructor.mapping, this)
  update: (data) -> 
    ko.mapping.fromJS(data, @constructor.mapping, this)
  getAttribute: (name) ->
    attribute = null
    for attr in @attributes()
      if attr.name is name
        attribute = attr
        break
    return attribute
  updateAttribute: (attrName, attrValue) ->
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

  getDeviceById: (id) -> ko.utils.arrayFirst(@devices(), (d) => d.id is id )


window.pimatic = new Pimatic({devices: [], rules: [], variables: [], devicepages: []})