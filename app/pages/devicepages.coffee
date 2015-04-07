# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", '#devicepages-page', tc (event) ->

  class DevicepagesViewModel

    enabledEditing: ko.observable(yes)
    isSortingDevicepages: ko.observable(no)

    constructor: () ->
      @devicepages = pimatic.devicepages

      @devicepagesListViewRefresh = ko.computed( tc =>
        @devicepages()
        @isSortingDevicepages()
        @enabledEditing()
        pimatic.try( => $('#devicepages').listview('refresh').addClass("dark-background") )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

    afterRenderDevicepage: (elements, devicepage) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())

    onDevicepagesSorted: (devicepage, eleBefore, eleAfter) =>
      pageOrder = []
      unless eleBefore?
        pageOrder.push devicepage.id 
      for g in @devicepages()
        if g is devicepage then continue
        pageOrder.push(g.id)
        if eleBefore? and g is eleBefore
          pageOrder.push(devicepage.id)
      pimatic.client.rest.updatePageOrder({pageOrder})
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)
  
    onDropDevicepageOnTrash: (devicepage) ->
      really = confirm(__("Do you really want to delete the %s devicepage?", devicepage.name()))
      if really then (doDeletion = =>
          pimatic.loading "deletedevicepage", "show", text: __('Saving')
          pimatic.client.rest.removePage(pageId: devicepage.id)
          .always( => 
            pimatic.loading "deletedevicepage", "hide"
          ).done(ajaxShowToast).fail(ajaxAlertFail)
        )()

    onAddDevicepageClicked: =>
      jQuery.mobile.pageParams = {action: 'add'}
      return true

    onEditDevicepageClicked: (page) =>
      jQuery.mobile.pageParams = {action: 'update', page: page}
      return true

  pimatic.pages.devicepages = devicepagesPage = new DevicepagesViewModel()

)

$(document).on("pagecreate", '#devicepages-page', tc (event) ->
  devicepagesPage = pimatic.pages.devicepages
  try
    ko.applyBindings(devicepagesPage, $('#devicepages-page')[0])
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $("#devicepages .handle").disableSelection()
  return
)

$(document).on("pagebeforeshow", '#devicepages-page', tc (event) ->
  pimatic.try( => $('#devicepages').listview('refresh').addClass("dark-background") )
)






