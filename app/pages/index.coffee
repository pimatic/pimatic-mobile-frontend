# index-page
# ----------
tc = pimatic.tryCatch

$(document).on("pagecreate", '#index', tc (event) ->

  class IndexViewModel
    # static property:
    @mapping = {
    }

    devicepages: pimatic.devicepages
    errorCount: pimatic.errorCount
    activeDevicepage: ko.observable(null)
    isSortingItems: ko.observable(no)
    enabledEditing: ko.observable(no)
    bindingsApplied: ko.observable(no)

    constructor: () ->
      @groups = pimatic.groups
      @rememberme = pimatic.rememberme

      @updateFromJs(
        ruleItemCssClass: ''
        hasRootCACert: no
      )

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

      @devicepagesTabsRefresh = ko.computed( tc =>
        unless @bindingsApplied() then return
        dPages =  @devicepages()
        enabledEditing = @enabledEditing()
        itemTabs = $("#item-tabs")
        pimatic.try => itemTabs.navbar "destroy"
        ko.cleanNode(itemTabs[0])
        if dPages.length > 0
          html = """
            <ul data-bind="foreach: devicepages">
              <li>
                <a 
                  data-ajax='false' 
                  data-bind="attr: {
                    href: '#item-tab-'+$data.id}, 
                    text: name, 
                    css: {'ui-btn-active': $data == $root.activeDevicepage()}, 
                    click: $root.onPageTabClicked"
                ></a>
              </li>
            </ul>
          """
        else html = """<ul></ul>"""
        itemTabs.html(html)
        ko.applyBindings(this, itemTabs[0])
        if enabledEditing
          itemTabs.find('ul').append($('#edit-devicepage-link-template').text())
        if dPages.length > 0 or @enabledEditing()
          itemTabs.navbar()
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      _devicePages = []

      ko.computed( tc () =>
        unless @bindingsApplied() then return
        dPages = @devicepages()
        diff = ko.utils.compareArrays(dPages, _devicePages)
        _devicePages = (p for p in dPages)
        changed = no
        for d in diff
          if d.status isnt 'retained'
            changed = true
            break
        unless changed then return
        console.log "rebuilding devicepages"
        itemLists = $('#item-lists')
        ko.cleanNode(itemLists[0])
        owl = itemLists.data('owlCarousel')
        if owl?
          owl.destroy()
        if dPages.length > 0
          html = $('#devicepages-template').text()
          itemLists.html(html)
          ko.applyBindings(this, itemLists[0]) if ko.dataFor($('#index')[0])?
          itemLists.find('[data-role="listview"]').listview()
          itemLists.owlCarousel({
            navigation: true
            slideSpeed: 300
            paginationSpeed: 400
            singleItem: true  
            #autoHeight: true
            pagination: false
            navigation: false
            lazyEffect: no
            lazyLoad: no
            afterAction: =>
              #itemLists.trigger( "updatelayout" )
            afterMove: (ele) =>
              current = ele.data('owlCarousel').currentItem
              @activeDevicepage(@devicepages()[current])
          })
        else
          itemLists.html('')
        return
       ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})


      @activeDevicepage.subscribe( (ap) =>
        unless ap? then return
        owl = $('#item-lists').data('owlCarousel')
        unless owl? then return
        index = @devicepages.indexOf(ap)
        if index is -1 then return
        owl.goTo(index)
      )

      ko.computed( =>
        dps = @devicepages()
        if dps.length is 0
          @activeDevicepage(null)
        else unless @activeDevicepage()?
          @activeDevicepage(dps[0])
      )

      @itemsListViewRefresh = ko.computed( tc =>
        dp.devices() for dp in @devicepages()
        g.devices() for g in pimatic.groups()
        @isSortingItems()
        @enabledEditing()
        pimatic.try( => 
          $('#item-lists [data-role="listview"]').each( ->
            lw = $(this)
            unless lw.data('mobileListview')? then lw.listview()
            else lw.listview('refresh')
          )
        )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @deviepagesRefresh = ko.computed( tc =>
        @devicepages()
        pimatic.try( => $('.nav-panel-menu').listview('refresh') )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})


      if pimatic.storage.isSet('pimatic.indexPage')
        data = pimatic.storage.get('pimatic.indexPage')
        try
          @updateFromJs(data)
        catch e
          TraceKit.report(e)
          pimatic.storage.removeAll()
          window.location.reload()

      @autosave = ko.computed( =>
        data = ko.mapping.toJS(this)
        pimatic.storage.set('pimatic.indexPage', data)
      ).extend(rateLimit: {timeout: 500, method: "notifyWhenChangesStop"})

      @toggleEditingText = ko.computed( tc => 
        unless @enabledEditing() 
          __('Edit lists')
        else
          __('Lock lists')
      )

    getItemTemplate: (deviceItem) =>
      return "#{deviceItem.getItemTemplate()}-template"

    showDevicePage: (devicePage) =>
      @activeDevicepage(devicePage)
      $("#nav-panel").panel( "close" );
      return true

    updateFromJs: (data) -> 
      ko.mapping.fromJS(data, IndexViewModel.mapping, this)

    onPageTabClicked: (page) =>
      @activeDevicepage(page)

    onAddItemClicked: =>
      return true

    # afterRenderItem: (elements, item) ->
    #   item.afterRender(elements)



    # updateItemOrder: (order) ->
    #   toIndex = (id) -> 
    #     index = $.inArray(id, order)
    #     if index is -1 # if not in array then move it to the back
    #       index = 999999
    #     return index
    #   @items.sort( (left, right) => toIndex(left.itemId) - toIndex(right.itemId) )

    # updateRuleOrder: (order) ->
    #   toIndex = (id) -> 
    #     index = $.inArray(id, order)
    #     if index is -1 # if not in array then move it to the back
    #       index = 999999
    #     return index
    #   @rules.sort( (left, right) => toIndex(left.id) - toIndex(right.id) )

    # updateVariable: (varInfo) ->
    #   for variable in @variables()
    #     if variable.name is varInfo.name
    #       variable.update(varInfo)
    #   for item in @items()
    #     if item.type is "variable" and item.name is varInfo.name
    #       item.value(varInfo.value)

    toggleEditing: =>
      @enabledEditing(not @enabledEditing())

    onItemsSorted: (item, eleBefore, eleAfter) =>

      addToGroup = (group, itemBefore) =>
        position = (
          unless itemBefore? then 0 
          else ko.utils.arrayIndexOf(group.devices(), itemBefore.device.id) + 1
        )
        if position is -1 then position = 0
        groupId = group.id

        pimatic.client.rest.addDeviceToGroup({deviceId: item.device.id, groupId: groupId, position: position})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

      removeFromGroup = ( (group) =>
        groupId = group.id
        pimatic.client.rest.removeDeviceFromGroup({deviceId: item.device.id, groupId: groupId})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )

      updatePageDeviceOrder = ( (itemBefore) =>
        devicesOrder = []
        unless itemBefore?
          devicesOrder.push item.device.id 
        for it in @activeDevicepage().devices()
          if it is item then continue
          devicesOrder.push(it.device.id)
          if itemBefore? and it is itemBefore
            devicesOrder.push(item.device.id)
        pimatic.client.rest.updatePage({pageId: @activeDevicepage().id, page: {devicesOrder}})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )
      
      if eleBefore?
        if eleBefore instanceof pimatic.DeviceItem then g1 = eleBefore.device.group()
        else if eleBefore.group instanceof pimatic.Group then g1 = eleBefore.group
        else g1 = null
        itemBefore = (if eleBefore instanceof pimatic.DeviceItem then eleBefore)
        g2 = item.device.group()

        if g1 isnt g2
          if g1?
            addToGroup(g1, itemBefore)
            updatePageDeviceOrder(itemBefore)
          else if g2?
            removeFromGroup(g2)
            updatePageDeviceOrder(itemBefore)
          else
            updatePageDeviceOrder(itemBefore)
        else
          updatePageDeviceOrder(itemBefore)

    onDropItemOnTrash: (item) =>
      really = confirm(__("Do you really want to delete the item?"))
      if really then (doDeletion = =>
          activePage = @activeDevicepage()
          pimatic.loading "deleteitem", "show", text: __('Saving')
          pimatic.client.rest.removeDeviceFromPage(
            deviceId: item.deviceId
            pageId: activePage.id
          ).always( => 
            pimatic.loading "deleteitem", "hide"
          ).done(ajaxShowToast).fail(ajaxAlertFail)
        )()

    toLoginPage: ->
      urlEncoded = encodeURIComponent(window.location.href)
      window.location.href = "/login?url=#{urlEncoded}"

  pimatic.pages.index = indexPage = new IndexViewModel()

  try
    ko.applyBindings(indexPage, $('#index')[0])
    indexPage.bindingsApplied(yes)
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $('#index').on("change", "#item-lists .switch", tc (event) ->
    switchDevice = ko.dataFor(this)
    switchDevice.onSwitchChange()
    return
  )

  $('#index').on("slidestop", " #item-lists .dimmer", tc (event) ->
    dimmerDevice = ko.dataFor(this)
    dimmerDevice.onSliderStop()
    return
  )

  $('#index').on("vclick", "#item-lists .shutter-down", tc (event) ->
    shutterDevice = ko.dataFor(this)
    shutterDevice.onShutterDownClicked()
    return false
  )

  $('#index').on("vclick", "#item-lists .shutter-up", tc (event) ->
    shutterDevice = ko.dataFor(this)
    shutterDevice.onShutterUpClicked()
    return false
  )

  $('#index').on("vclick", '#item-tabs .edit-handle', tc (event) -> 
    indexPage.onEditPageClicked(ko.dataFor(this))
    return false
  )

  $('#index').on("vclick", '#item-tabs #add-devicepage-link', tc (event) -> 
    indexPage.onAddPageClicked()
    return true
  )

  $("#items .handle").disableSelection()

  $("#nav-panel").on('panelopen panelclose', tc (event) ->
    itemList = $('#item-lists')
    if itemList.is(":visible")
      pimatic.try => itemList.data('owlCarousel').updateVars()
  )
  return
)


$(document).on('click', '.content-overlay', tc (event) ->
  $('#nav-panel').panel( "close" )
)

$(document).on("pageshow", '#index', tc (event) ->
  pimatic.try => $('#item-lists').data('owlCarousel').updateVars()
)

$(document).on("pagebeforeshow", '#index', tc (event) ->
  setTimeout( (->
    pimatic.try => $('#nav-panel').find('[data-role="listview"]').listview('refresh')
    pimatic.try => $('#item-lists').find('[data-role="listview"]').listview('refresh')
    pimatic.try => $("#item-tabs").navbar()
  ), 2)
)



