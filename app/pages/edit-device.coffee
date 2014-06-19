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

    constructor: ->
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add New Device') else __('Edit Device'))
      )

      editorEle = $('#device-json-editor')
      editor = null
      @deviceClass.subscribe( (className) =>
        if className?
          console.log "change editor ", className
          pimatic.client.rest.getDeviceConfigSchema({className}).done( (result) =>
            schema = result.configSchema
            delete schema.id
            delete schema.name
            delete schema.class
            if editor?
              editor.destroy()
              #editorEle.html('')
            editor = new JSONEditor(editorEle[0], {
              disable_collapse: yes
              disable_properties: yes
              disable_edit_json: yes
              theme: 'jquerymobile'
              schema: {
                title: className
                type: 'object'
                properties: schema
              }
            });
            console.log editor
          )
      )

    resetFields: () ->
      @deviceName('')
      @deviceId('')
      @deviceClass('')

    onSubmit: ->
      params = {
        deviceId: @deviceId()
        device: 
          name: @deviceName()
      }

      (
        switch @action()
          when 'add' then pimatic.client.rest.addDevice(params)
          when 'update' then pimatic.client.resultt.updateDevice(params)
          else throw new Error("Illegal devicedevice action: #{action()}")
      ).done( (data) ->
        if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      really = confirm(__("Do you really want to delete the %s device?", @deviceName()))
      if really
        pimatic.client.rest.removeDevice({deviceId: @deviceId()})
          .done( (data) ->
            if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
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

  $('#edit-device', '#device-json-editor button', (e) =>
    console.log e
    e.preventDefault();
    return
  )
)


