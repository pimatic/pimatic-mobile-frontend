# edit-variable-page
# --------------

#merge = Array.prototype.concat
#LazyLoad.js(merge.apply(scripts.jsoneditor))

wrap = (schema, value) ->
  unless schema?
    return ko.observable(value)
  switch schema.type
    when "string", "number", "integer", "boolean"
      return ko.observable(value)
    when "object"
      unless value? then return ko.observable(value)
      if schema.properties?
        for name, prop of schema.properties
          value[name] = wrap prop, value[name]
      return ko.observable(value)
    when "array"
      unless value? then return ko.observableArray(value)
      for ele, i in value
        value[i] = wrap schema.items, value[i]
      return ko.observableArray(value)
    else
      # no type given?
      return ko.observable(value)

unwrap = (value) ->
  value = ko.unwrap(value)
  unless value? then return value
  unwraped = value
  type = if Array.isArray(value) then 'array' else typeof value
  switch type
    when "object"
      unwraped = {}
      for name, prop of value
        unwraped[name] = unwrap prop
    when "array"
      unwraped = []
      for ele, i in value
        unwraped[i] = unwrap ele
  return unwraped

getDefaultValue = (schema) =>
  if schema.defaut?
    return schema.default
  if schema.enum?.length > 0
    return schema.enum[0]
  switch schema.type
    when "string" then ""
    when "number", "integer" then 0
    when "boolean" then false
    when "object" then {}
    when "array" then []


$(document).on("pagebeforecreate", '#edit-device-page', (event) ->
  if pimatic.pages.editDevice? then return
  
  class EditDeviceViewModel

    action: ko.observable('add')
    deviceName: ko.observable('')
    deviceId: ko.observable('')
    deviceClass: ko.observable('')
    deviceClasses: ko.observableArray()
    deviceConfig: ko.observable({})
    configSchema: ko.observable(null)
    editor: null

    constructor: ->
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add New Device') else __('Edit Device'))
      )

      editorEle = $('#device-json-editor')
      pimatic.autoFillId(@deviceName, @deviceId, @action)
      
      editorSetConfig = (config) =>
        unless @editor? then return
        deviceConfig = @deviceConfig()
        confCopy = {}
        count = 0
        for k, v of deviceConfig
          unless k in ['name', 'id', 'class']
            confCopy[k] = v
            count++
        unless count is 0 then @editor.setValue(confCopy)

      getProperties = (data) ->
        unless data.schema.properties?
          return []
        parentValue = ko.unwrap(data.value)
        unless parentValue?
          parentValue = {}
          data.value(parentValue)
        props = []
        for name, prop of data.schema.properties
          if prop.definedBy?
            definedByValue = ko.unwrap(parentValue[prop.definedBy])
            if definedByValue? and definedByValue of prop.options
              prop = prop.options[definedByValue]
          propValue = unwrap parentValue[name]
          if (not propValue?) and data.schema.required? and name in data.schema.required
            propValue = getDefaultValue prop
          parentValue[name] = wrap(prop, propValue)
          props.push({ schema: prop, value: parentValue[name] })
        return props

      getItems = (value) ->
        unless ko.unwrap(value)?
          return []
        return ( { schema: @items or {}, value: v} for v in ko.unwrap(value) )

      onEditItemClick = (index, data) ->
        data.schema.editingItem({
          schema: data.schema, 
          value: wrap(data.schema, unwrap(data.value))
          index: index
        })

      editOk = (parent, data) ->
        editingItem = data.schema.editingItem()
        if editingItem.index?
          array = parent.value()
          array[editingItem.index](editingItem.value())
          parent.value(array)
        else
          parent.value.push(editingItem.value)
        data.schema.editingItem(null)  

      editCancel = (data) ->
        data.schema.editingItem(null)

      addItem = (data) ->
        if data.schema.items.default?
          # copy
          value = wrap(data.schema.items, JSON.parse(JSON.stringify(data.schema.items.default)))
        else
          value = wrap data.schema.items, getDefaultValue(data.schema.items)
        data.schema.items.editingItem(schema: data.schema.items, value: value)
        return     

      getItemLabel = (value) ->
        unwraped = unwrap value
        if @type is "object" and @properties?
          label = ""
          if @properties.name? 
            label = unwraped.name
          if @properties.id?
            if label.length > 0
              label += " (#{unwraped.id})"
            else
              label = unwraped.id
          if label? and label.length > 0 then return label
        return JSON.stringify(unwraped)

      enhanceSchema = (schema, name) ->
        schema.name = name
        schema.notDefault = (data) => 
          ko.pureComputed(
            read: => data.value?()?
            write: (notDefault) =>
              if notDefault
                defaultValue = data.schema.default
                unless defaultValue?
                  defaultValue = getDefaultValue(data.schema)
                data.value(defaultValue)
              else
                data.value(undefined)
          )

        schema.enabled = (data) => data.value?()?

        schema.valueOrDefault = (data) => 
          ko.pureComputed(
            read: => if data.value?()? then data.value() else data.schema.default
            write: (value) => 
              if data.schema.type in ["number", "integer"]
                value = parseFloat(value)
              data.value(value)
          )

        switch schema.type
          #when 'string', 'number', "integer"
          when 'object'
            schema.getProperties = getProperties
            if schema.properties?
              for name, prop of schema.properties
                if schema.required?
                  prop.notRequired = not (name in schema.required)
                enhanceSchema(prop, name)
                if prop.defines?.property?
                  definedProp = schema.properties[prop.defines.property]
                  definedProp.options = prop.defines.options
                  definedProp.definedBy = name
                  for optName, option of definedProp.options
                    enhanceSchema(option, prop.defines.property)
          when 'array'
            schema.getItems = getItems
            unless schema.items?
              schema.items = {}
            schema.items.getItemLabel = getItemLabel
            schema.items.onEditItemClick = onEditItemClick
            schema.items.editOk = editOk
            schema.items.editCancel = editCancel
            schema.items.addItem = addItem
            schema.items.editingItem = ko.observable(null)
            schema.items.isSorting = ko.observable(false)
            schema.items.onSorted = (data) =>
              return (item, eleBefore, eleAfter) =>
                itemIndex = 0
                newIndex = 0
                array = data.value()
                item = item.value()
                eleBefore = (if eleBefore? then eleBefore.value() else null)
                eleAfter = (if eleAfter? then eleAfter.value() else null)
                for i in [0...array.length]
                  if array[i]() is item
                    itemIndex = i
                  if array[i]() is eleAfter
                    newIndex = i-1
                unless eleBefore?
                  newIndex = 0
                unless eleAfter?
                  newIndex =array.length-1
                if itemIndex isnt newIndex
                  array.splice(itemIndex, 1)
                  array.splice(newIndex, 0, ko.observable(item))
                  data.value(array)
            schema.items.onRemove = (data) =>
              return (item) =>
                array = data.value()
                item = item.value()
                for i in [0...array.length]
                  if array[i]() is item
                    array.splice(i, 1)
                    data.value(array)
                    return
            enhanceSchema(schema.items, null)
          when "string", "number", "integer", "boolean"
            if schema.defines?.options?
              if not schema.enum?
                schema.enum = Object.keys(schema.defines.options)
        return

      @deviceClass.subscribe( (className) =>
        if className? and typeof className is "string" and className.length > 0
          pimatic.client.rest.getDeviceConfigSchema({className}).done( (result) =>
            if result.success?
              schema = result.configSchema
              delete schema.properties.id
              delete schema.properties.name
              delete schema.properties.class
              unwraped = unwrap(@deviceConfig())
              rewraped = wrap(schema, unwraped)
              @deviceConfig(rewraped())
              # console.log JSON.stringify(schema, null, 2);
              enhanceSchema schema, null
              @configSchema(schema)
          )
        else
          @configSchema(null)
      )

    afterRenderItem: (elements, device) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    resetFields: () ->
      @deviceName('')
      @deviceId('')
      @deviceConfig({})
      @deviceClass('')

    onSubmit: ->
      deviceConfig = unwrap @deviceConfig()
      deviceConfig.id = @deviceId()
      deviceConfig.name = @deviceName()
      deviceConfig.class = @deviceClass()
      # console.log deviceConfig
      (
        switch @action()
          when 'add' then pimatic.client.rest.addDeviceByConfig({deviceConfig})
          when 'update' then pimatic.client.rest.updateDeviceByConfig({deviceConfig})
          else throw new Error("Illegal devicedevice action: #{action()}")
      ).done( (data) ->
        if data.success then $.mobile.changePage '#devices-page', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      really = confirm(__("Do you really want to delete the %s device?", @deviceName()))
      if really
        pimatic.client.rest.removeDevice({deviceId: @deviceId()})
          .done( (data) ->
            if data.success then $.mobile.changePage '#devices-page', {transition: 'slide', reverse: true}   
            else alert data.error
          ).fail(ajaxAlertFail)
      return false

  try
    pimatic.pages.editDevice = new EditDeviceViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#edit-device-page', (event) ->
  pimatic.client.rest.getDeviceClasses({}).done( (result) =>
    if result.success
      deviceClasses = [""].concat result.deviceClasses
      pimatic.pages.editDevice.deviceClasses(deviceClasses)
  )
)

$(document).on("pagecreate", '#edit-device-page', (event) ->
  try
    ko.applyBindings(pimatic.pages.editDevice, $('#edit-device-page')[0])
  catch e
    TraceKit.report(e)
)


$(document).on("pagebeforeshow", '#edit-device-page', (event) ->
  editDevicePage = pimatic.pages.editDevice
  params = jQuery.mobile.pageParams
  jQuery.mobile.pageParams = {}
  if params?.action is "update"
    device = params.device
    editDevicePage.action('update')
    editDevicePage.deviceId(device.id)
    editDevicePage.deviceName(device.name())
    editDevicePage.deviceClass(null)
    editDevicePage.configSchema(null)
    editDevicePage.deviceConfig(device.config)
    deviceClasses = pimatic.pages.editDevice.deviceClasses()
    unless device.config.class in deviceClasses
      deviceClasses.push device.config.class
      editDevicePage.deviceClasses(deviceClasses)
    editDevicePage.deviceClass(device.config.class)
  else
    editDevicePage.resetFields()
    editDevicePage.action('add')
  return
)
