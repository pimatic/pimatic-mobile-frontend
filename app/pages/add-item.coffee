# add-item-page
# ----------
tc = pimatic.tryCatch

# class DeviceEntry
#   constructor: (device) ->
#     @id = device.id
#     @name = device.name
#     @isAdded = ko.computed( =>
#       return yes
#       # items = pimatic.pages.index.items()
#       # match = ko.utils.arrayFirst(items, (item) =>
#       #   return item.type is 'device' and item.deviceId is @id
#       # )
#       # return match?
#     )
#     @icon = ko.computed( => if @isAdded() then 'check' else 'plus' )


class AddItemViewModel

  constructor: ->

    @devices = pimatic.devices

    @refreshDeviceListView = ko.computed( =>
      @devices()
      pimatic.try => $('#device-items').listview('refresh')
    ).extend(rateLimit: {timeout: 10, method: "notifyWhenChangesStop"})

    # @refreshVariableListView = ko.computed( =>
    #   @variables()
    #   $('#variable-items').listview('refresh')
    # ).extend(rateLimit: {timeout: 10, method: "notifyWhenChangesStop"})


  addDeviceToIndexPage: (device) ->
    if device.isAdded() then return
    $.get("/add-device/#{device.id}")
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)

  addVariableToIndexPage: (variable) ->
    if variable.isAdded() then return
    $.get("/add-variable/#{variable.name}")
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)


tc( => pimatic.pages.addItem = new AddItemViewModel() )()

$(document).on "pagecreate", '#add-item', tc (event) ->
  ko.applyBindings(pimatic.pages.addItem, $('#add-item')[0])

  $('#device-items').on "click", 'li.item', tc ->
    li = $(this)
    pimatic.pages.addItem.addDeviceToIndexPage(ko.dataFor(li[0]))
    return

  $('#variable-items').on "click", 'li.item', tc ->
    li = $(this)
    pimatic.pages.addItem.addVariableToIndexPage(ko.dataFor(li[0]))
    return

  $('#add-other').on "click", '#add-a-header', tc ->
    $("<div>").simpledialog2(
      themeDialog: 'a'
      themeButtonDefault: 'b'
      mode: "button"
      headerText: __("Name")
      headerClose: true
      buttonPrompt: __("Please enter a name")
      buttonInput: true
      zindex: 1001
      buttons:
        OK:
          text: __('Add')
          click: ->
            name = $.mobile.sdLastInput
            if name is ""
              pimatic.showToast __("Please enter a name")
            else
              $.get("/add-header/#{name}").done((result) ->
                pimatic.showToast __("Header added")
              ).fail(ajaxAlertFail)
    )
    setTimeout ( -> $('.ui-simpledialog-input').focus() ), 1
    return

  $('#add-other').on "click", '#add-a-button', tc ->
    $("<div>").simpledialog2(
      themeDialog: 'a'
      themeButtonDefault: 'b'
      mode: "button"
      headerText: __("Name")
      headerClose: true
      buttonPrompt: __("Please enter a name")
      buttonInput: true
      zindex: 1001
      buttons:
        OK:
          text: __('Add')
          click: ->
            name = $.mobile.sdLastInput
            if name is ""
              pimatic.showToast __("Please enter a name")
            else
              $.get("/add-button/#{name}").done((result) ->
                pimatic.showToast __("Button added")
              ).fail(ajaxAlertFail)
    )
    setTimeout ( -> $('.ui-simpledialog-input').focus() ), 1
    return
  return

$(document).on "pageshow", '#add-item', tc (event) ->
  return






