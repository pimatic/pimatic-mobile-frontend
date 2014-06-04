# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", tc (event) ->
  # Just execute it one time
  if pimatic.pages.index? then return
  class IndexViewModel
    # static property:
    @mapping = {
    }

    devicepages: pimatic.devicepages
    activeDevicepage: ko.observable(null)
    isSortingItems: ko.observable(no)

    constructor: () ->

      @updateFromJs(
        errorCount: 0
        enabledEditing: no
        rememberme: no
        showAttributeVars: no
        ruleItemCssClass: ''
        hasRootCACert: no
        updateProcessStatus: 'idle'
        updateProcessMessages: []
      )

      @updateProcessStatus.subscribe( tc (status) =>
        switch status
          when 'running'
            pimatic.loading "update-process-status", "show", {
              text: __('Installing updates, Please be patient')
            }
          else
            pimatic.loading "update-process-status", "hide"
      )

      @setupStorage()

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

      @devicepagesTabsRefresh = ko.computed( tc =>
        dPages =  @devicepages()
        itemTabs = $("#item-tabs")
        pimatic.try => itemTabs.navbar "destroy"
        ko.cleanNode(itemTabs[0])
        if dPages.length > 0
          html = """
            <ul data-bind="foreach: devicepages">
              <li>
                <a data-ajax='false' data-bind="attr: {href: '#item-tab-'+$data.id}, text: name, css: {'ui-btn-active': $data.isActive}, click: $root.onPageTabClicked"></a>
              </li>
            </ul>
          """ 
          itemTabs.html(html)
          ko.applyBindings(this, itemTabs[0])
          $("#item-tabs").navbar()
        else
          itemTabs.html('')
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @devicepagesTabsRefresh = ko.computed( tc =>
        dPages =  @devicepages()
        itemLists = $('#item-lists')
        ko.cleanNode(itemLists[0])
        owl = itemLists.data('owlCarousel')
        if owl?
          owl.destroy()
        if dPages.length > 0
          html = ''
          for page, i in dPages
            html += """
              <div>
                <ul data-role="listview" data-pageid="#{page.id}" class="items">
                <!-- ko template: { name: $root.getItemTemplate, foreach: devicepages()[#{i}].devices, afterRender: devicepages()[#{i}].afterRender } --><!-- /ko -->
                </ul>
              </div>
            """
          itemLists.html(html)
          for page in dPages
            pageUl = itemLists.find("ul[data-pageid=#{page.id}]")
          ko.applyBindings(this, itemLists[0])
          itemLists.find('[data-role="listview"]').listview()
          itemLists.owlCarousel({
            navigation: true
            slideSpeed: 300
            paginationSpeed: 400
            singleItem: true  
            #autoHeight: true
            pagination: false
            navigation: false
            afterAction: =>
              itemLists.trigger( "updatelayout" )
            afterMove: (ele) =>
              current = ele.data('owlCarousel').currentItem
              @activeDevicepage(@devicepages()[current])
          })
        else
          itemLists.html('')
        
       ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @activeDevicepage.subscribe( (ap) =>
        unless ap? then return
        owl = $('#item-lists').data('owlCarousel')
        unless owl? then return
        index = @devicepages.indexOf(ap)
        if index is -1 then return
        owl.goTo(index)
      )

      @devicepages.subscribe( (dps) =>
        if dps.length is 0
          @activeDevicepage(null)
        else unless @activeDevicepage()?
          @activeDevicepage(dps[0])
      )

      @itemsListViewRefresh = ko.computed( tc =>
        dp.devices() for dp in @devicepages()
        @isSortingItems()
        @enabledEditing()
        pimatic.try( => 
          $('#item-lists [data-role="listview"]').each( ->
            lw = $(this)
            unless lw.data('mobileListview')? then lw.listview()
            else lw.listview('refresh').addClass("dark-background")
          )
        )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @deviepagesRefresh = ko.computed( tc =>
        @devicepages()
        pimatic.try( => $('.nav-panel-menu').listview('refresh').addClass("dark-background") )
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

      sendToServer = yes
      @rememberme.subscribe( tc (shouldRememberMe) =>
        if sendToServer
          $.get("remember", rememberMe: shouldRememberMe)
            .done(ajaxShowToast)
            .fail( => 
              sendToServer = no
              @rememberme(not shouldRememberMe)
            ).fail(ajaxAlertFail)
        else 
          sendToServer = yes
        # swap storage
        allData = pimatic.storage.get('pimatic')
        pimatic.storage.removeAll()
        if shouldRememberMe
          pimatic.storage = $.localStorage
        else
          pimatic.storage = $.sessionStorage
        pimatic.storage.set('pimatic', allData)
      )

      @toggleEditingText = ko.computed( tc => 
        unless @enabledEditing() 
          __('Edit lists')
        else
          __('Lock lists')
      )

    getItemTemplate: (deviceItem) ->
      return "#{deviceItem.getItemTemplate()}-template"

    setupStorage: ->
      if $.localStorage.isSet('pimatic')
        # Select localStorage
        pimatic.storage = $.localStorage
        $.sessionStorage.removeAll()
        @rememberme(yes)
      else if $.sessionStorage.isSet('pimatic')
        # Select sessionSotrage
        pimatic.storage = $.sessionStorage
        $.localStorage.removeAll()
        @rememberme(no)
      else
        # select sessionStorage as default
        pimatic.storage = $.sessionStorage
        @rememberme(no)
        pimatic.storage.set('pimatic', {})


    updateFromJs: (data) -> 
      ko.mapping.fromJS(data, IndexViewModel.mapping, this)

    onPageTabClicked: (page) =>
      @activeDevicepage(page)


    # afterRenderItem: (elements, item) ->
    #   item.afterRender(elements)

    # removeItem: (itemId) ->
    #   @items.remove( (item) => item.itemId is itemId )

    # removeRule: (ruleId) ->
    #   @rules.remove( (rule) => rule.id is ruleId )

    # removeVariable: (varName) ->
    #   @variables.remove( (variable) => variable.name is varName )


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

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())
      pimatic.loading "enableediting", "show", text: __('Saving')
      $.ajax("/enabledEditing/#{@enabledEditing()}",
        global: false # don't show loading indicator
      ).always( ->
        pimatic.loading "enableediting", "hide"
      ).done(ajaxShowToast)

    onItemsSorted: ->
      order = (item.itemId for item in @items())
      pimatic.loading "itemorder", "show", text: __('Saving')
      $.ajax("update-item-order", 
        type: "POST"
        global: false
        data: {order: order}
      ).always( ->
        pimatic.loading "itemorder", "hide"
      ).done(ajaxShowToast)
      .fail(ajaxAlertFail)

    onDropItemOnTrash: (item) ->
      really = confirm(__("Do you really want to delete the item?"))
      if really then (doDeletion = =>
          pimatic.loading "deleteitem", "show", text: __('Saving')
          $.post('remove-item', itemId: item.itemId).done( (data) =>
            if data.success
              @items.remove(item)
          ).always( => 
            pimatic.loading "deleteitem", "hide"
          ).done(ajaxShowToast).fail(ajaxAlertFail)
        )()

    toLoginPage: ->
      urlEncoded = encodeURIComponent(window.location.href)
      window.location.href = "/login?url=#{urlEncoded}"

  pimatic.pages.index = indexPage = new IndexViewModel()

  pimatic.socket.on("welcome", tc (data) ->
    indexPage.updateFromJs(data)
  )

  pimatic.socket.on("device-attribute", tc (attrEvent) -> 
    indexPage.updateDeviceAttribute(attrEvent.id, attrEvent.name, attrEvent.value)
  )

  pimatic.socket.on("variable", tc (variable) -> indexPage.updateVariable(variable))

  pimatic.socket.on("item-add", tc (item) -> indexPage.addItemFromJs(item))
  pimatic.socket.on("item-remove", tc (itemId) -> indexPage.removeItem(itemId))
  pimatic.socket.on("item-order", tc (order) -> indexPage.updateItemOrder(order))

  pimatic.socket.on("rule-add", tc (rule) -> indexPage.updateRuleFromJs(rule))
  pimatic.socket.on("rule-update", tc (rule) -> indexPage.updateRuleFromJs(rule))
  pimatic.socket.on("rule-remove", tc (ruleId) -> indexPage.removeRule(ruleId))
  pimatic.socket.on("rule-order", tc (order) -> indexPage.updateRuleOrder(order))

  pimatic.socket.on("variable-add", tc (variable) -> indexPage.addVariableFromJs(variable))
  pimatic.socket.on("variable-remove", tc (variableName) -> indexPage.removeVariable(variableName))
  pimatic.socket.on("variable-order", tc (order) -> indexPage.updateVariableOrder(order))

  pimatic.socket.on("update-process-status", tc (status) -> indexPage.updateProcessStatus(status))
  pimatic.socket.on("update-process-message", tc (msg) -> indexPage.updateProcessMessages.push msg)

  pimatic.socket.on('log', tc (entry) -> 
    if entry.level is "error" then indexPage.errorCount(indexPage.errorCount() + 1)
  )
  return
)

$(document).on("pagecreate", '#index', tc (event) ->


  indexPage = pimatic.pages.index
  try
    ko.applyBindings(indexPage, $('#index')[0])
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $('#index #items').on("change", ".switch", tc (event) ->
    switchDevice = ko.dataFor(this)
    switchDevice.onSwitchChange()
    return
  )

  $('#index #items').on("slidestop", ".dimmer", tc (event) ->
    dimmerDevice = ko.dataFor(this)
    dimmerDevice.onSliderStop()
    return
  )

  $('#index #items').on("vclick", ".shutter-down", tc (event) ->
    shutterDevice = ko.dataFor(this)
    shutterDevice.onShutterDownClicked()
    return false
  )

  $('#index #items').on("vclick", ".shutter-up", tc (event) ->
    shutterDevice = ko.dataFor(this)
    shutterDevice.onShutterUpClicked()
    return false
  )

  # $('#index #items').on("click", ".device-label", (event, ui) ->
  #   deviceId = $(this).parents(".item").data('item-id')
  #   device = pimatic.devices[deviceId]
  #   unless device? then return
  #   div = $ "#device-info-popup"
  #   div.find('.info-id .info-val').text device.id
  #   div.find('.info-name .info-val').text device.name
  #   div.find(".info-attr").remove()
  #   for attrName, attr of device.attributes
  #     attr = $('<li class="info-attr">').text(attr.label)
  #     div.find("ul").append attr
  #   div.find('ul').listview('refresh')
  #   div.popup "open"
  #   return
  # )

  $("#items .handle").disableSelection()
  return
)






