# index-page
# ----------
tc = pimatic.tryCatch

$(document).on("pagecreate", '#index', tc (event) ->

  class IndexViewModel
    # static property:
    @mapping = {
      $default: 'ignore'
      ruleItemCssClass: 'observe'
      hasRootCACert: 'observe',
      collapsedGroups: 'observe'
    }

    devicepages: pimatic.devicepages
    errorCount: pimatic.errorCount
    activeDevicepage: ko.observable(null)
    isSortingItems: ko.observable(no)
    enabledEditing: ko.observable(no)
    bindingsApplied: ko.observable(no)

    constructor: () ->
      @groups = pimatic.groups
      @hasPermission = pimatic.hasPermission

      @updateFromJs(
        ruleItemCssClass: ''
        hasRootCACert: no,
        collapsedGroups: {}
      )

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

      @logoutText = ko.computed( tc =>
        if typeof pimatic.username() is "string"
          return __('Logout') + ' (' + pimatic.username() + ")"
        else
          return __('Logout')
      )

      itemTabs = null
      itemLists = null
      headroom = null
      headroomOptions = {
        offset: 40,
        tolerance: 10,
        classes: {
          initial: "animated",
          pinned: "slideDown",
          unpinned: "slideUp"
        }
      }

      lastNavbarWidth = null
      lastNavbarHeight = null
      updateNavbarLayoutTimeput = null
      updateNavbarLayout = (recheck = true) =>
        if itemTabs? and itemLists?
          index = if @activeDevicepage()? then @devicepages.indexOf(@activeDevicepage()) else 0
          width = $(itemLists.find('.items')[index]).width()
          if width isnt lastNavbarWidth
            itemTabs.css(
              width: width
            )
          height = itemTabs.height()
          if height isnt lastNavbarHeight
            itemLists.find('.items').each( () ->
              $(this).parent().css('padding-top', height)
            )
          clearTimeout(updateNavbarLayoutTimeput)
          if recheck
            updateNavbarLayoutTimeput = setTimeout((->
              updateNavbarLayout(false)
            ), 350)
          lastNavbarWidth = width
          lastNavbarHeight = height


      @devicepagesTabsRefresh = ko.computed( tc =>
        unless @bindingsApplied() then return
        dPages =  @devicepages()
        enabledEditing = @enabledEditing()
        itemTabs = $("#item-tabs")
        headroom?.destroy()
        pimatic.try => itemTabs.navbar "destroy"
        ko.cleanNode(itemTabs[0])
        if dPages.length > 0 and @hasPermission('pages', 'read')
          html = """
            <ul data-bind="foreach: devicepages">
              <li class="page-tab">
                <a 
                  data-ajax='false' 
                  data-bind="
                    attr: {
                      href: '#item-tab-'+$data.id
                    }, 
                    text: name, 
                    css: {'ui-btn-active': $data == $root.activeDevicepage()}
                  "
                ></a>
              </li>
            </ul>
          """
        else html = """<ul></ul>"""
        itemTabs.html(html)
        ko.applyBindings(this, itemTabs[0])
        if enabledEditing
          itemTabs.find('ul').append($('#edit-devicepage-link-template').text())
        if (dPages.length > 0 or @enabledEditing()) and @hasPermission('pages', 'read')
          itemTabs.navbar()
          itemTabs.find('ul').removeClass('ui-grid-a ui-grid-duo')
          lis = itemTabs.find('li')
          if lis.length <= 6
            liWidth = (100/lis.length) + "%"
            fullRow = lis.length
          else
            fullRow = Math.ceil(lis.length/2)
            liWidth = (100/fullRow) + "%"
          lis.each( (i) ->
            $(this)
              .css({'width': liWidth, 'clear': 'none'})
              .removeClass('ui-block-a ui-block-b ui-block-c ui-block-d ui-block-e')
              .addClass('ui-block-a')
            liA = $(this).find('a')
            liA.css('border-top-width', 0) if i+1 > fullRow
            #liA.css('border-right-width', liA.css('border-left-width')) if (i+1)%fullRow is 0
          )
          headroom = new Headroom(itemTabs[0], headroomOptions)
          headroom.init()
        updateNavbarLayout()
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      updateHeadroom = () =>
        if headroom? and @activeDevicepage()?
          headroom.destroy()
          # find scroller
          index = @devicepages.indexOf(@activeDevicepage())
          headroomOptions.scroller = itemLists.find('.owl-wrapper .owl-item')[index]
          headroom = new Headroom(itemTabs[0], headroomOptions)
          headroom.init()

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
        itemLists = $('#item-lists')
        ko.cleanNode(itemLists[0])
        owl = itemLists.data('owlCarousel')
        if owl?
          owl.destroy()
        if dPages.length > 0 and @hasPermission('pages', 'read')
          html = $('#devicepages-template').text()
          itemLists.html(html)
          ko.applyBindings(this, itemLists[0]) if ko.dataFor($('#index')[0])?
          itemLists.find('[data-role="listview"]').listview()
          itemLists.owlCarousel({
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
            afterUpdate: =>
              updateNavbarLayout()
          })
          lastCarouselWidth = itemLists.width()
          updateHeadroom()
        else
          itemLists.html('')
        updateNavbarLayout()
        return
       ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @activeDevicepage.subscribe( (ap) =>
        unless ap? then return
        owl = $('#item-lists').data('owlCarousel')
        unless owl? then return
        index = @devicepages.indexOf(ap)
        if index is -1 then return
        owl.goTo(index)
        updateHeadroom()
        updateNavbarLayout()
      )

      ko.computed( =>
        dps = @devicepages()
        if dps.length is 0
          @activeDevicepage(null)
        else unless @activeDevicepage()?
          @activeDevicepage(dps[0])
        else if not (@activeDevicepage() in dps)
          @activeDevicepage(dps[0])
      )

      @itemsListViewRefresh = ko.computed( tc =>
        dp.devices() for dp in @devicepages()
        g.devices() for g in pimatic.groups()
        @isSortingItems()
        @enabledEditing()
        @collapsedGroups()
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
        data = ko.mapper.toJS(this, IndexViewModel.mapping)
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
      $("#nav-panel").panel( "close" )
      return true

    updateFromJs: (data) -> 
      ko.mapper.fromJS(data, IndexViewModel.mapping, this)

    onAddItemClicked: =>
      return true

    onLogMessageClicked: =>
      jQuery.mobile.pageParams = {
        selectErrors: yes
      }
      return true

    onLogoutClicked: =>
      $.ajax({
        type: "GET"
        url: '/logout'
      }).fail( (jqXHR, textStatus, errorThrown) =>
        if textStatus is 'Unauthorized' or errorThrown is 'Unauthorized'
          setTimeout( =>
            pimatic.storage.removeAll()
            pimatic.showToast(jqXHR.responseText)
            window.location.reload()
          , 100)
        else
          ajaxAlertFail(jqXHR, textStatus, errorThrown)
      )
      return false

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
        else if eleBefore instanceof pimatic.Group then g1 = eleBefore
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

    createToggleGroupCallback: (page, group) =>
      fullId = "#{page.id}$#{group.id}"
      return () =>
        collapsed = @collapsedGroups()
        if collapsed[fullId]
          delete collapsed[fullId]
        else
          collapsed[fullId] = true
        @collapsedGroups(collapsed)
        return false;

    isGroupCollapsed: (page, group) => 
      fullId = "#{page.id}$#{group.id}"
      return @collapsedGroups()[fullId] is true

  pimatic.pages.index = indexPage = new IndexViewModel()

  try
    ko.applyBindings(indexPage, $('#index')[0])
    indexPage.bindingsApplied(yes)
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $('#index').on("vclick", ".page-tab", tc (event) ->
    page = ko.dataFor(this)
    indexPage.activeDevicepage(page)
    return false
  )

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

  # $('#index').on("vclick", '#item-tabs .edit-handle', tc (event) -> 
  #   indexPage.onEditPageClicked(ko.dataFor(this))
  #   return false
  # )

  $('#index').on("vclick", '#item-tabs #add-devicepage-link', tc (event) -> 
    indexPage.onAddPageClicked()
    return true
  )

  $("#items .handle").disableSelection()



  $("#nav-panel").on('panelopen panelclose', tc (event) ->
    itemList = $('#item-lists')
    if itemList.is(":visible") then updateCarousel()
  )

  $(document).on "vclick", '#to-graph-page', ->
    deviceId = $('#to-graph-page').attr('data-deviceId')
    device = pimatic.getDeviceById(deviceId)
    jQuery.mobile.pageParams = {
      device: device
    }
    jQuery.mobile.changePage '#graph-page', transition: 'slide'

  $(document).on "vclick", '#to-device-editor-page', ->
    deviceId = $('#to-device-editor-page').attr('data-deviceId')
    device = pimatic.getDeviceById(deviceId)
    jQuery.mobile.pageParams = {action: 'update', device: device, back: '#index'}
    jQuery.mobile.changePage '#edit-device-page', transition: 'slide'

  $(document).on "vclick", '#to-device-xButton', ->
    deviceId = $('#to-device-xButton').attr('data-deviceId')
    device = pimatic.getDeviceById(deviceId)
    device.rest.xButton({})
    .done( (response) =>
      if response.success
        eval(response.result)
      else
        throw new Error("xButton call failed: #{response.result}!")
    )
    .fail(ajaxAlertFail)

  return
)

lastCarouselWidth = 0
updateCarousel = ->
  pimatic.try => 
    itemList = $('#item-lists')
    width = itemList.width()
    if width isnt lastCarouselWidth
      itemList.data('owlCarousel').updateVars()
    lastCarouselWidth = width


$(document).on('click', '.content-overlay', tc (event) ->
  $('#nav-panel').panel( "close" )
)

$(document).on("pageshow", '#index', tc (event) ->
  updateCarousel()
  setTimeout(( ->
    updateCarousel()
    $.mobile.resetActivePageHeight()
  ), 1)
)

$(document).on("pagebeforeshow", '#index', tc (event) ->
  setTimeout( (->
    pimatic.try => $('#nav-panel').find('[data-role="listview"]').listview('refresh')
    pimatic.try => $('#item-lists').find('[data-role="listview"]').listview('refresh')
    pimatic.try => $("#item-tabs").navbar()
  ), 2)
)



