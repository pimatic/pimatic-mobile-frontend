# edit-variable-page
# --------------

merge = Array.prototype.concat
LazyLoad.js(merge.apply(scripts.jsonschemaeditor))

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

      pimatic.autoFillId(@deviceName, @deviceId, @action)

      @deviceClass.subscribe( (className) =>
        if className? and typeof className is "string" and className.length > 0
          pimatic.client.rest.getDeviceConfigSchema({className}).done( (result) =>
            if result.success?
              schema = result.configSchema
              delete schema.properties.id
              delete schema.properties.name
              delete schema.properties.class
              unwraped = jsonschemaeditor.unwrap(@deviceConfig())
              rewraped = jsonschemaeditor.wrap(schema, unwraped)
              @deviceConfig(rewraped())
              # console.log JSON.stringify(schema, null, 2);
              jsonschemaeditor.enhanceSchema schema, null
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
      deviceConfig = jsonschemaeditor.unwrap @deviceConfig()
      errors = []
      jsonschemaeditor.validate @configSchema(), deviceConfig, errors
      if errors.length > 0
        alert(errors.join("\n"))
        return
      deviceConfig.id = @deviceId()
      deviceConfig.name = @deviceName()
      deviceConfig.class = @deviceClass()

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

  fill = (action, deviceId, deviceName, deviceConfig) =>
    editDevicePage.action(action)
    editDevicePage.deviceId(deviceId)
    editDevicePage.deviceName(deviceName)
    editDevicePage.deviceClass(null)
    editDevicePage.configSchema(null)
    editDevicePage.deviceConfig(deviceConfig)
    deviceClasses = pimatic.pages.editDevice.deviceClasses()
    unless deviceConfig.class in deviceClasses
      deviceClasses.push deviceConfig.class
      editDevicePage.deviceClasses(deviceClasses)
    editDevicePage.deviceClass(deviceConfig.class)

  if params?.action is "update"
    device = params.device
    fill('update', device.id, device.name(), device.config)
  else if params?.action is "discovered"
    discoveredDevice = params.discoveredDevice
    fill('add', '', discoveredDevice.deviceName, discoveredDevice.config)
  else
    editDevicePage.resetFields()
    editDevicePage.action('add')
  return
)
