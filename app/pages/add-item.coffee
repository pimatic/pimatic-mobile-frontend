# add-item-page
# ----------


class DeviceEntry

  constructor: (data) ->
    @id = data.id
    @name = ko.observable(data.name)
    @isAdded = ko.computed( =>
      items = pimatic.pages.index.items()
      match = ko.utils.arrayFirst(items, (item) =>
        return item.type is 'device' and item.deviceId is @id
      )
      return match?
    )
    @icon = ko.computed( => if @isAdded() then 'check' else 'plus' )

  update: (data) ->
    @name(data.name)

class AddItemViewModel
  devices: ko.observableArray([])

  constructor: ->
    @refreshListView = ko.computed( =>
      @devices()
      $('#device-items').listview('refresh')
    ).extend(rateLimit: {timeout: 10, method: "notifyWhenChangesStop"})

  updateDevicesFromJs: (devices) ->
    mapping = {
      create: ({data, parent, skip}) => new DeviceEntry(data)
      update: ({data, parent, target}) =>
        target.update(data)
        return target
      key: (data) => data.id
    }
    ko.mapping.fromJS(devices, mapping, @devices)

  addDeviceToIndexPage: (device) ->
    if device.isAdded() then return
    $.get("/add-device/#{device.id}")
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)


pimatic.pages.addItem = new AddItemViewModel()

$(document).on "pagecreate", '#add-item', (event) ->
  ko.applyBindings(pimatic.pages.addItem, $('#add-item')[0])

  $('#device-items').on "click", 'li.item', ->
    li = $(this)
    pimatic.pages.addItem.addDeviceToIndexPage(ko.dataFor(li[0]))
    return

  $('#add-other').on "click", '#add-a-header', ->
    $("<div>").simpledialog2
      mode: "button"
      headerText: __("Name")
      headerClose: true
      buttonPrompt: __("Please enter a name")
      buttonInput: true
      buttons:
        OK:
          click: ->
            name = $.mobile.sdLastInput
            if name is ""
              pimatic.showToast __("Please enter a name")
            else
              $.get("/add-header/#{name}").done((result) ->
                pimatic.showToast __("Header added")
              ).fail(ajaxAlertFail)
    setTimeout ( -> $('.ui-simpledialog-input').focus() ), 1
    return

  $('#add-other').on "click", '#add-a-button', ->
    $("<div>").simpledialog2
      mode: "button"
      headerText: __("Name")
      headerClose: true
      buttonPrompt: __("Please enter a name")
      buttonInput: true
      buttons:
        OK:
          click: ->
            name = $.mobile.sdLastInput
            if name is ""
              pimatic.showToast __("Please enter a name")
            else
              $.get("/add-button/#{name}").done((result) ->
                pimatic.showToast __("Button added")
              ).fail(ajaxAlertFail)
    setTimeout ( -> $('.ui-simpledialog-input').focus() ), 1
    return
  return

$(document).on "pageshow", '#add-item', (event) ->

  $.get("/api/devices")
    .done( (data) -> 
      pimatic.pages.addItem.updateDevicesFromJs(data.devices) 
    ).fail(ajaxAlertFail)
  return






