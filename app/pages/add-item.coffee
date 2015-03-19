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

  isDeviceAdded: (device) =>
    devicesOnPage = pimatic.pages.index?.activeDevicepage()?.devices
    unless devicesOnPage? then return no
    match = ko.utils.arrayFirst(devicesOnPage(), (d) =>
      return d.deviceId is device.id
    )
    return match?

  deviceEntryIcon: (device) => ( if @isDeviceAdded(device) then 'check' else 'plus' )

  addDeviceToIndexPage: (device) ->
    if @isDeviceAdded(device) then return
    activeDevicepage = pimatic.pages.index?.activeDevicepage()
    unless activeDevicepage? then return
    pimatic.client.rest.addDeviceToPage({
      pageId:activeDevicepage.id,
      deviceId: device.id
    }).done(ajaxShowToast)
      .fail(ajaxAlertFail)



tc( => pimatic.pages.addItem = new AddItemViewModel() )()

$(document).on "pagecreate", '#add-item-page', tc (event) ->
  ko.applyBindings(pimatic.pages.addItem, $('#add-item-page')[0])

  $('#device-items').on "click", 'li.item', tc ->
    li = $(this)
    pimatic.pages.addItem.addDeviceToIndexPage(ko.dataFor(li[0]))
    return

$(document).on "pageshow", '#add-item-page', tc (event) ->
  return






