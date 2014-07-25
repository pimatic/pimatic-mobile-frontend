# edit-variable-page
# --------------

$(document).on("pagebeforecreate", (event) ->
  if pimatic.pages.editDevice? then return
  
  class EditDeviceViewModel

    action: ko.observable('add')
    deviceName: ko.observable('')
    deviceId: ko.observable('')
    deviceClass: ko.observable('')
    deviceClasses: ko.observableArray()
    deviceConfig: ko.observable({})
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
        console.log "confCopy:", confCopy
        unless count is 0 then @editor.setValue(confCopy)

      @deviceClass.subscribe( (className) =>
        if @editor?
          @editor.destroy()
          @editor = null
        if className? and typeof className is "string" and className.length > 0
          pimatic.client.rest.getDeviceConfigSchema({className}).done( (result) =>
            if result.success?
              schema = result.configSchema
              delete schema.properties.id
              delete schema.properties.name
              delete schema.properties.class
              console.log "schema:", result.configSchema
              @editor = new JSONEditor(editorEle[0], {
                disable_collapse: yes
                disable_properties: yes
                disable_edit_json: yes
                theme: 'jquerymobile'
                schema: schema
              });
              @editor.on('ready', =>
                editorSetConfig(@deviceConfig())
              )
          )
      )
      # @deviceConfig.subscribe( (config) =>
      #   editorSetConfig(config)
      # )


    resetFields: () ->
      @deviceName('')
      @deviceId('')
      @deviceConfig({})
      @deviceClass('')

    onSubmit: ->
      deviceConfig = @editor.getValue();
      deviceConfig.id = @deviceId()
      deviceConfig.name = @deviceName()
      deviceConfig.class = @deviceClass()

      (
        switch @action()
          when 'add' then pimatic.client.rest.addDeviceByConfig({deviceConfig})
          when 'update' then pimatic.client.rest.updateDeviceByConfig({deviceConfig})
          else throw new Error("Illegal devicedevice action: #{action()}")
      ).done( (data) ->
        if data.success then $.mobile.changePage '#devicepages-page', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      really = confirm(__("Do you really want to delete the %s device?", @deviceName()))
      if really
        pimatic.client.rest.removeDevice({deviceId: @deviceId()})
          .done( (data) ->
            if data.success then $.mobile.changePage '#devicepages-page', {transition: 'slide', reverse: true}   
            else alert data.error
          ).fail(ajaxAlertFail)
      return false

  try
    pimatic.pages.editDevice = new EditDeviceViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#edit-device', (event) ->
  pimatic.client.rest.getDeviceClasses({}).done( (result) =>
    if result.success
      pimatic.pages.editDevice.deviceClasses(result.deviceClasses)
  )
)


$(document).on("pagecreate", '#edit-device', (event) ->
  try
    ko.applyBindings(pimatic.pages.editDevice, $('#edit-device')[0])
  catch e
    TraceKit.report(e)
)


