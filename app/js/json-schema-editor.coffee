
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
          propValue = value[name]
          if not propValue? and prop?.type?
            if prop.type in ["array", "object"]
              propValue = prop.default
          value[name] = wrap prop, propValue
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

isNoNum = (value) ->
  (typeof value is 'string' and value.length is 0) or isNaN(value)

validate = (schema, value, errors, parent) ->
  unless value? then return
  switch schema.type
    when "string" then return
    when "boolean" then return
    when "object"
      if schema.properties and schema.properties?
        for name, prop of schema.properties
          if prop.definedBy?
            definedByValue = value[prop.definedBy]
            if definedByValue? and definedByValue of prop.options
              prop = prop.options[definedByValue]
          propValue = value[name]
          if propValue? and prop.type in ["number", "integer"]
            if isNoNum propValue
              errors.push("#{name} must be a number")
            else
              value[name] = parseFloat(propValue)
          validate prop, propValue, errors, value
    when "array"
      if schema.items?
        for i in [0...value.length]
          propValue = value[i]
          if propValue? and schema.items.type in ["number", "integer"]
            if isNoNum propValue
              errors.push("#{name} must be a number")
            else
              value[i] = parseFloat(propValue)
          validate schema.items, propValue, errors, value

getDefaultValue = (schema) ->
  if schema.defaut?
    return schema.default
  if schema.enum?.length > 0
    return schema.enum[0]
  switch schema.type
    when "string" then ""
    when "number", "integer" then ""
    when "boolean" then false
    when "object" then {}
    when "array" then []

getProperties = (data) ->
  unless data.schema.properties?
    return []
  parentValue = ko.unwrap(data.value)
  unless parentValue?
    parentValue = {}
    data.value(parentValue)
  props = []
  for name, prop of data.schema.properties
    propValue = unwrap parentValue[name]
    if prop.definedBy?
      definedByValue = ko.unwrap(parentValue[prop.definedBy])
      if definedByValue? and definedByValue of prop.options
        commonProp = prop
        commonProp.definedByValue = commonProp.definedByValue or definedByValue
        prop = prop.options[definedByValue]
        commonProp.values = commonProp.values or {}
        commonProp.values[commonProp.definedByValue] = propValue
        commonProp.definedByValue = definedByValue
        propValue = commonProp.values[definedByValue]
    if (not propValue?) and data.schema.required? and name in data.schema.required
      propValue = getDefaultValue prop
    parentValue[name] = wrap(prop, propValue)
    props.push({ schema: prop, value: parentValue[name] })
  return props

getExtraProperties = (data) ->
  unless data.schema.extraProperties?
    return []
  parentValue = ko.unwrap(data.value)
  unless parentValue?
    parentValue = {}
    data.value(parentValue)
  extraProperties = data.schema.extraProperties()
  modified = false
  for name, val of parentValue
    unless name of extraProperties or name of (data.schema.properties or {})
      val = unwrap val
      if typeof val isnt "undefined"
        newScheme = {type: typeof val, isExtra: true}
        enhanceSchema(newScheme, name)
        extraProperties[name] = newScheme
        modified = true
  if modified
    data.schema.extraProperties(extraProperties)
  props = []
  for name, prop of extraProperties
    propValue = unwrap parentValue[name]
    parentValue[name] = wrap(prop, propValue)
    props.push({ schema: prop, value: parentValue[name], parent: data })
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

addNewProperty = (data) ->
  name = data.schema.newPropertyName()
  if name.length is 0
    alert('Name can not be empty')
    return
  type = data.schema.newPropertyType()
  schema = {type: type, isExtra: true}
  enhanceSchema(schema, name)
  parentValue = data.value()
  parentValue[name] = getDefaultValue(schema)
  data.value(parentValue)
  extraProperties = data.schema.extraProperties()
  extraProperties[name] = schema
  data.schema.extraProperties(extraProperties)
  data.schema.newPropertyName("")
  data.schema.newPropertyType("string")

removeExtraProperty = (data) ->
  name = data.schema.name
  parentValue = unwrap data.parent.value
  delete parentValue[name]
  extraProperties = data.parent.schema.extraProperties()
  delete extraProperties[name]
  data.parent.value(parentValue)
  data.parent.schema.extraProperties(extraProperties)

getItemLabel = (value) ->
  unwraped = unwrap value
  if @type is "object" and @properties?
    label = ""
    if @nameProperty? and unwraped[@nameProperty]?
      label = unwraped[@nameProperty]
    else if @properties.name? 
      label = unwraped.name
    else if @properties.id?
      if label.length > 0
        label += " (#{unwraped.id})"
      else
        label = unwraped.id
    if label? and label.length > 0 then return label
    return JSON.stringify(unwraped)
  else
    return "#{unwraped}"

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
        data.value(value)
    )

  switch schema.type
    #when 'string', 'number', "integer"
    when 'object'
      schema.getProperties = getProperties
      schema.allowAdditionalProperties = (
        not schema.properties? or typeof schema.additionalProperties is "object"
      )
      if schema.allowAdditionalProperties
        schema.newPropertyName = ko.observable("")
        schema.newPropertyType = ko.observable("string")
        if typeof schema.additionalProperties is "object" and schema.additionalProperties.type?
          schema.extraPropertiesDescription = schema.additionalProperties.description
          schema.newPropertyTypes = [schema.additionalProperties.type]
        else
          schema.newPropertyTypes = ["string", "number", "boolean", "object"]
        schema.newPropertyAdd = addNewProperty
        schema.extraProperties = ko.observable({})
        schema.getExtraProperties = getExtraProperties
        schema.removeExtraProperty = removeExtraProperty
      if schema.properties?
        schema.hasProperties = Object.keys(schema.properties).length > 0
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
      else
        schema.hasProperties = false
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
      itemName = schema.items.name or "#{name} Item"
      if name? and (matches = name.match(/^(.+)s/))?
        itemName = matches[1]
      enhanceSchema(schema.items, itemName)
    when "string", "number", "integer", "boolean"
      if schema.defines?.options?
        if not schema.enum?
          schema.enum = Object.keys(schema.defines.options)
  return

window.jsonschemaeditor = {wrap, unwrap, enhanceSchema, validate}