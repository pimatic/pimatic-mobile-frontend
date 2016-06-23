# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", '#devices-page', tc (event) ->

  class DevicesViewModel

    enabledEditing: ko.observable(yes)
    isSortingDevices: ko.observable(no)
    discoverMessages: ko.observableArray([])
    discoveredDevices: ko.observableArray([])

    constructor: () ->
      @devices = pimatic.devices
      @groups = pimatic.groups
      @hasPermission = pimatic.hasPermission

      data = pimatic.storage.get('pimatic.devices') or {}
      @collapsedGroups = ko.observable(data.collapsed or {})

      @devicesListViewRefresh = ko.computed( tc =>
        @collapsedGroups()
        @devices()
        @isSortingDevices()
        @enabledEditing()
        @discoveredDevices()
        g.devices() for g in @groups()
        pimatic.try( => $('#devices').listview('refresh') )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

      @getUngroupedDevices =  ko.computed( tc =>
        ungroupedDevices = []
        groupedDevices = []
        for g in @groups()
          groupedDevices = groupedDevices.concat g.devices()
        for d in @devices()
          if ko.utils.arrayIndexOf(groupedDevices, d.id) is -1
            ungroupedDevices.push d
        return ungroupedDevices
      )

    afterRenderDevice: (elements, device) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())

    onDevicesSorted: (device, eleBefore, eleAfter) =>

      addToGroup = (group, deviceBefore) =>
        position = (
          unless deviceBefore? then 0 
          else ko.utils.arrayIndexOf(group.devices(), deviceBefore.id) + 1
        )
        if position is -1 then position = 0
        groupId = group.id

        pimatic.client.rest.addDeviceToGroup({deviceId: device.id, groupId: groupId, position: position})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

      removeFromGroup = ( (group) =>
        groupId = group.id
        pimatic.client.rest.removeDeviceFromGroup({deviceId: device.id, groupId: groupId})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )

      updateDeviceOrder = ( (deviceBefore) =>
        deviceOrder = []
        unless deviceBefore?
          deviceOrder.push device.id 
        for r in @devices()
          if r is device then continue
          deviceOrder.push(r.id)
          if deviceBefore? and r is deviceBefore
            deviceOrder.push(device.id)
        pimatic.client.rest.updateDeviceOrder({deviceOrder})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )

      updateGroupDeviceOrder = ( (group, deviceBefore) =>
        devicesOrder = []
        unless deviceBefore?
          devicesOrder.push device.id 
        for deviceId in group.devices()
          if deviceId is device.id then continue
          devicesOrder.push(deviceId)
          if deviceBefore? and deviceId is deviceBefore.id
            devicesOrder.push(device.id)
        pimatic.client.rest.updateGroup({groupId: group.id, group:{devicesOrder}})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )
      
      if eleBefore?
        if eleBefore instanceof pimatic.Device then g1 = eleBefore.group()
        else if eleBefore instanceof pimatic.Group then g1 = eleBefore
        else g1 = null
        deviceBefore = (if eleBefore instanceof pimatic.Device then eleBefore)
        g2 = device.group()

        if g1 isnt g2
          if g1?
            addToGroup(g1, deviceBefore)
          else if g2?
            removeFromGroup(g2)
          else
            updateDeviceOrder(deviceBefore)
        else
          if g1?
            updateGroupDeviceOrder(g1, deviceBefore)
          else
            updateDeviceOrder(deviceBefore)

    onDropDeviceOnTrash: (device) ->
      really = confirm(__("Do you really want to delete the %s device?", device.name()))
      if really then (doDeletion = =>
        pimatic.loading "deletedevice", "show", text: __('Saving')
        pimatic.client.rest.removeDevice(deviceId: device.id)
        .always( => 
          pimatic.loading "deletedevice", "hide"
        ).done(ajaxShowToast).fail(ajaxAlertFail)
      )()

    onAddDeviceClicked: ->
      unless @hasPermission('devices', 'write')
        pimatic.showToast(__("Sorry, you have no permissions to edit this device."))
        return false
      jQuery.mobile.pageParams = {action: 'add'}
      return true

    onEditDeviceClicked: (device) =>
      unless @hasPermission('devices', 'write')
        pimatic.showToast(__("Sorry, you have no permissions to edit this device."))
        return false
      jQuery.mobile.pageParams = {action: 'update', device: device}
      return true

    onDiscoveredDeviceClicked: (discoveredDevice) =>
      unless @hasPermission('devices', 'write')
        pimatic.showToast(__("Sorry, you have no permissions to edit this device."))
        return false
      jQuery.mobile.pageParams = {action: 'discovered', discoveredDevice}
      return true

    toggleGroup: (group) =>
      collapsed = @collapsedGroups()
      if collapsed[group.id]
        delete collapsed[group.id]
      else
        collapsed[group.id] = true
      @collapsedGroups(collapsed)
      @saveCollapseState()
      return false

    isGroupCollapsed: (group) => @collapsedGroups()[group.id] is true

    saveCollapseState: () =>
      data = pimatic.storage.get('pimatic.devices') or {}
      data.collapsed = @collapsedGroups()
      pimatic.storage.set('pimatic.devices', data)

    discoverDevices: () =>
      time = 20000 #ms
      @discoverMessages([])
      @discoveredDevices([])
      pimatic.client.rest.discoverDevices({time})
      .done( =>
        pimatic.loading "discoverdevices", "show", text: __('Searching for devices')
        setTimeout(( =>
          @discoverMessages([])
          pimatic.loading "discoverdevices", "hide"
        ), time)
      )
      .fail(ajaxAlertFail)


  pimatic.pages.devices = devicesPage = new DevicesViewModel()

)

$(document).on("pagecreate", '#devices-page', tc (event) ->
  devicesPage = pimatic.pages.devices
  try
    ko.applyBindings(devicesPage, $('#devices-page')[0])
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $("#devices .handle").disableSelection()

  pimatic.socket.on('discoverMessage', (data) =>
    devicesPage.discoverMessages.push(data)
  )

  pimatic.socket.on('deviceDiscovered', (data) =>
    devicesPage.discoveredDevices.push(data)
  )

  return
)

$(document).on("pagebeforeshow", '#devices-page', tc (event) ->
  pimatic.try( => $('#devices').listview('refresh') )
)






