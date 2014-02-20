# index-page
# ----------

$(document).on "pagecreate", '#index', (event) ->
  pimatic.pages.index.fixScrollOverDraggableRule()

  pimatic.socket.on "device-attribute", (attrEvent) -> 
    pimatic.pages.index.updateDeviceAttribute attrEvent
    if attrEvent.name is "state"
      value = if attrEvent.value then "on" else "off" 
      $("#flip-#{attrEvent.id}").val(value).slider('refresh')
    if attrEvent.name is "dimlevel"
      $("#slider-#{attrEvent.id}").val(attrEvent.value).slider('refresh')

  pimatic.socket.on "rule-add", (rule) -> pimatic.pages.index.addRule rule
  pimatic.socket.on "rule-update", (rule) -> pimatic.pages.index.updateRule rule
  pimatic.socket.on "rule-remove", (rule) -> pimatic.pages.index.removeRule rule
  pimatic.socket.on "item-add", (item) -> pimatic.pages.index.addItem item
  pimatic.socket.on "item-remove", (item) -> pimatic.pages.index.removeItem item
  pimatic.socket.on "item-order", (order) -> pimatic.pages.index.reorderItems order
  pimatic.socket.on "rule-order", (order) -> pimatic.pages.index.reorderRules order

  $('#index #items').on "slidestop", ".switch", (event, ui) ->
    ele = $(this)
    val = ele.val()
    deviceId = ele.data('device-id')
    deviceAction = if val is 'on' then 'turnOn' else 'turnOff'
    ele.slider('disable')
    pimatic.loading "switch-on-#{deviceId}", "show", text: __("switching #{val}")
    $.ajax("/api/device/#{deviceId}/#{deviceAction}",
      global: no
    ).done(
      ajaxShowToast
    ).fail( 
      -> ele.val(if val is 'on' then 'off' else 'on').slider('refresh')
    ).always(-> 
      pimatic.loading "switch-on-#{deviceId}", "hide"
      # element could be not existing anymore
      pimatic.try => ele.slider('enable')
    ).fail(ajaxAlertFail)
    return

  sliderValBefore = 0
  $('#index #items').on "slidestart", ".dimmer", (event, ui) ->
    sliderValBefore = $(this).val()

  $('#index #items').on "slidestop", ".dimmer", (event, ui) ->
    ele = $(this)
    val = ele.val()
    deviceId = ele.data('device-id')
    $.get("/api/device/#{deviceId}/changeDimlevelTo", dimlevel: val)
      .done(ajaxShowToast)
      .fail( => 
        pimatic.try => ele.val(sliderValBefore).slider('refresh') 
      ).fail(ajaxAlertFail)
    return

  $('#index #items').on "click", ".device-label", (event, ui) ->
    deviceId = $(this).parents(".item").data('item-id')
    device = pimatic.devices[deviceId]
    unless device? then return
    div = $ "#device-info-popup"
    div.find('.info-id .info-val').text device.id
    div.find('.info-name .info-val').text device.name
    div.find(".info-attr").remove()
    for attrName, attr of device.attributes
      attr = $('<li class="info-attr">').text(attr.label)
      div.find("ul").append attr
    div.find('ul').listview('refresh')
    div.popup "open"
    return

  $('#index #items').on "click", ".button a", (event, ui) ->
    ele = $(this).parents('.item')
    name = ele.data('name')
    $.get("/button-pressed/#{name}").fail(ajaxAlertFail)
    return
  
  $('#index #rules').on "click", ".rule a", (event, ui) ->
    ruleId = $(this).data('rule-id')
    rule = pimatic.rules[ruleId]
    $('#edit-rule-form').data('action', 'update')
    $('#edit-rule-condition').val(rule.condition)
    $('#edit-rule-actions').val(rule.action)
    $('#edit-rule-active').prop "checked", rule.active
    $('#edit-rule-id').val(ruleId)
    return

  $('#index #rules').on "click", "#add-rule a", (event, ui) ->
    $('#edit-rule-form').data('action', 'add')
    $('#edit-rule-condition').val("")
    $('#edit-rule-actions').val("")
    $('#edit-rule-id').val("")
    $('#edit-rule-active').prop "checked", true
    return

  $('#index').on "click", "#lock-button", (event, ui) ->
    enabled = not pimatic.pages.index.editingMode
    pimatic.pages.index.changeEditingMode(enabled)
    pimatic.loading "enableediting", "show", text: __('Saving')
    $.ajax("/enabledEditing/#{enabled}",
      global: false # don't show loading indicator
    ).always( ->
      pimatic.loading "enableediting", "hide"
    ).done(ajaxShowToast)

  $("#items").sortable(
    items: "li.sortable"
    forcePlaceholderSize: true
    placeholder: "sortable-placeholder"
    handle: ".handle"
    cursor: "move"
    revert: 100
    scroll: true
    start: (ev, ui) ->
      $("#delete-item").show()
      $("#add-a-item").hide()
      $('#items').listview('refresh')
      ui.item.css('border-bottom-width', '1px')

    stop: (ev, ui) ->
      $("#delete-item").hide()
      $("#add-a-item").show()
      $('#items').listview('refresh')
      ui.item.css('border-bottom-width', '0')
      order = for item in $("#items li.sortable")
        item = $ item
        type: item.data('item-type'), id: item.data('item-id')
      pimatic.loading "itemorder", "show", text: __('Saving')
      $.ajax("update-item-order", 
        type: "POST"
        global: false
        data: {order: order}
      ).always( ->
        pimatic.loading "itemorder", "hide"
      ).done(ajaxShowToast).fail(ajaxAlertFail)
  )

  $("#rules").sortable(
    items: "li.sortable"
    forcePlaceholderSize: true
    placeholder: "sortable-placeholder"
    handle: ".handle"
    cursor: "move"
    revert: 100
    scroll: true
    start: (ev, ui) -> console.log "start sorting"
    stop: (ev, ui) ->
      $('#rules').listview('refresh')
      order = ($(item).data('rule-id') for item in $("#rules .rule a"))
      pimatic.loading "ruleorder", "show", text: __('Saving')
      $.ajax("update-rule-order",
        type: "POST"
        global: false
        data: {order: order}
      ).always( ->
        pimatic.loading "ruleorder", "hide"
      ).done(ajaxShowToast).fail(ajaxAlertFail)
  )

  $("#items .handle, #rules .handle").disableSelection()

  $("#delete-item").droppable(
    accept: "li.sortable"
    hoverClass: "ui-state-hover"
    drop: (ev, ui) ->
      item = {
        id: ui.draggable.data('item-id')
        type: ui.draggable.data('item-type')
      }
      pimatic.loading "deleteitem", "show", text: __('Saving')
      $.post('remove-item', item: item).done( (data) ->
        if data.success
          if item.type is 'device'
             delete pimatic.devices[item.id]
          ui.draggable.remove()
      ).always( -> 
        pimatic.loading "deleteitem", "hide"
      ).done(ajaxShowToast).fail(ajaxAlertFail)
  )


  $('#nav-panel').on "change", '#rememberme', (event, ui) ->
    rememberMe = $(this).is(':checked')
    if pimatic.storage.rememberMe is rememberMe then return
    $.get("remember", rememberMe: rememberMe)
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)
      .done( (data) =>
        unless data.success then return
        # get data and empty storage
        pmData = pimatic.storage.get('pmData')
        pimatic.storage.removeAll()
        pimatic.rememberMe = rememberMe
        pmData.rememberMe = rememberMe
        # swap storage
        if rememberMe
          pimatic.storage = $.localStorage
        else
          pimatic.storage = $.sessionStorage
        pimatic.storage.set('pmData', pmData)
      )
    return

  $('#rememberme').prop('checked', pimatic.rememberMe)

  pimatic.socket.on 'connect', ->
    pimatic.pages.index.loadData()

  pimatic.socket.on 'log', (entry) -> 
    if entry.level is 'error' 
      pimatic.pages.index.updateErrorCount()

  unless pimatic.pages.index.hasData
    data = pimatic.storage.get('pmData.data')
    if data? then pimatic.pages.index.buildAll(data)

  pimatic.pages.index.pageCreated = yes
  pimatic.pages.index.loadData()

pimatic.pages.index =
  loading: no
  hasData: no
  pageCreated: false
  editingMode: yes

  loadData: ->
    # already loading?
    pimatic.loading "datadelay", "hide"
    if pimatic.pages.index.loading then return
    pimatic.pages.index.loading = yes

    if pimatic.pages.index.hasData
      pimatic.loading "loadingdata", "show", text: __("Refreshing") 
    else
      pimatic.loading "loadingdata", "show", { text: __("Loading"), blocking: yes }

    $.ajax("/data.json",
      global: no
      data: 'noAuthPromp=true'
    ).done( (data) ->
        pimatic.pages.index.buildAll(data)
        pimatic.loading "loadingdata", "hide"
      ).always( ->
        pimatic.pages.index.loading = no
        if pimatic.pages.index.hasData is yes
          pimatic.loading "loadingdata", "hide"
      ).fail( (jqXHR)->
        ###
          We don't want the user get spammed with browser http basic auth dialogs so
          we redirect to a not offline avilable page, where he can enter
          the auth information and is then redirected back here
        ###
        if jqXHR.status is 401 then return pimatic.pages.index.toLoginPage()
        # if we are not connected to the socket, the data gets refrashed anyway so don't get it
        # else try again after a delay 
        if pimatic.socket.socket.connected
          pimatic.loading("datadelay", "show",
            text: __("could not load data, retrying in %s seconds", "5")
          )
          setTimeout( ->
            pimatic.pages.index.loadData()
          , 5000)
      )
    return

  toLoginPage: ->
    prot = window.location.protocol
    host = window.location.host
    urlEncoded = encodeURIComponent(window.location)
    window.location = "#{prot}//user:pw@#{host}/login?url=#{urlEncoded}" 

  buildAll: (data) ->
    pimatic.devices = []
    pimatic.rules = []
    $('#items .item').remove()
    pimatic.pages.index.addItem(item) for item in data.items
    $('#rules .rule').remove()
    pimatic.pages.index.addRule(rule) for rule in data.rules
    pimatic.errorCount = data.errorCount
    pimatic.pages.index.updateErrorCount()
    pimatic.pages.index.changeEditingMode data.enabledEditing
    pimatic.pages.index.hasData = yes
    pimatic.storage.set('pmData.data', data)
    $('.drag-message').text('').fadeOut().removeClass('activate').removeClass('deactivate')

  updateErrorCount: ->
    if $('#error-count').find('.ui-btn-text').length > 0
      $('#error-count').find('.ui-btn-text').text(pimatic.errorCount)
      try
        $('#error-count').button('refresh')
      catch e
        # ignore button not initialised
    else
      $('#error-count').text(pimatic.errorCount)
    if pimatic.errorCount is 0 then $('#error-count').hide()
    else $('#error-count').show()
    return

  changeEditingMode: (enabled) ->
    pimatic.pages.index.editingMode = enabled
    icon = null
    if enabled
      $('#index').removeClass('locked').addClass('unlocked')
      icon = 'check'
    else 
      $('#index').addClass('locked').removeClass('unlocked')
      icon = 'gear'
    if pimatic.pages.index.pageCreated
      $('#lock-button').buttonMarkup(icon: icon)
    else
      $('#lock-button').attr('data-icon', icon)
    return

  addItem: (item) ->
    li = if item.template?
      switch item.template 
        when "switch" then pimatic.pages.index.buildSwitch(item)
        when "dimmer" then pimatic.pages.index.buildDimmer(item)
        else pimatic.pages.index.buildDevice(item)
    else switch item.type
      when 'device'
        item.template = 'device'
        pimatic.pages.index.buildDevice(item)
      when 'header' then pimatic.pages.index.buildHeader(item)
      when 'button' then pimatic.pages.index.buildButton(item)
      else pimatic.pages.index.buildDevice(item)
    li.data('item-type', item.type)
    li.data('item-id', item.id)
    li.addClass 'item'
    $('#add-a-item').before li
    li.find("label").before $('<div class="ui-icon-alt handle">
      <div class="ui-icon ui-icon-bars"></div>
    </div>')
    $('#items').listview('refresh') if pimatic.pages.index.pageCreated

  removeItem: (item) ->
    for li in $('#items .item')
      li = $ li
      if item.id is li.data('item-id')
        li.remove()
    if item.type is 'device'
      delete pimatic.devices[item.id]

  reorderItems: (order) ->
    #detactch all items
    items = $('#items .item')
    items.detach()
    for o in order
      # find the matching item
      for i in items
        i = $ i
        # reappend it
        if i.data('item-id') is o.id
          i.insertBefore('#add-a-item')

  buildSwitch: (device) ->
    pimatic.devices[device.id] = device
    li = $ $('.switch-template').html()
    li.attr('id', "device-#{device.id}")
    li.find('label')
      .attr('for', "flip-#{device.id}")
      .text(device.name)
    select = li.find('select')
      .attr('name', "flip-#{device.id}")
      .attr('id', "flip-#{device.id}")             
      .data('device-id', device.id)
      val = if device.attributes.state.value then 'on' else 'off'
      select.find("option[value=#{val}]").attr('selected', 'selected')
    select
      .slider() 
    return li

  buildDimmer: (device) ->
    pimatic.devices[device.id] = device
    li = $ $('.dimmer-template').html()
    li.attr('id', "device-#{device.id}")
    li.find('label')
      .attr('for', "slider-#{device.id}")
      .text(device.name)
    input = li.find('input')
      .attr('name', "slider-#{device.id}")
      .attr('id', "slider-#{device.id}")             
      .data('device-id', device.id)
    val = device.attributes.dimlevel.value
    input.val(val)
    input.slider() 
    return li

  buildDevice: (device) ->
    pimatic.devices[device.id] = device
    li = $ $(".#{device.template}-template").html()
    if li.length is 0
      console.log "Could not find template #{device.template}. Falling back to default."
      li = $ $(".device-template").html()
    li.attr('id', "device-#{device.id}")
    li.find('label').text(device.name)
    if device.error?
      li.find('.error').text(device.error)

    attributesSpan = li.find('.attributes')
    for attrName of device.attributes
      attr = device.attributes[attrName]
      span = $ $('.attribute-template').html()
      span.addClass("attr-#{attrName}")
      span.addClass("attr-type-#{attr.type}")
      attributesSpan.addClass("contains-attr-#{attrName}")
      attributesSpan.addClass("contains-attr-type-#{attr.type}")
      span.attr('data-val', attr.value)
      span.find('.val').text(pimatic.pages.index.attrValueToText attr)
      span.find('.unit').text(attr.unit)
      attributesSpan.append span
    return li

  buildHeader: (header) ->
    li = $ $('.header-template').html()
    li.find('label').text(header.text)
    return li

  buildButton: (button) ->
    li = $ $('.button-template').html()
    li.data('name', button.text)
    li.find('label').text(__("%s button", button.text))
    li.find('a').text(button.text).button()
    return li

  attrValueToText: (attribute) ->
    if attribute.value is null or not attribute.value?
      return __("unknown")
    if attribute.type is 'Boolean'
      unless attribute.labels? then return attribute.value.toString()
      else if attribute.value is true then attribute.labels[0] 
      else if attribute.value is false then attribute.labels[1]
      else attribute.value.toString()
    else return attribute.value.toString()

  updateDeviceAttribute: (attrEvent) ->
    attr = pimatic.devices[attrEvent.id]?.attributes?[attrEvent.name]
    unless attr? then return
    attr.value = attrEvent.value
    li = $("#device-#{attrEvent.id}")
    span = li.find(".attr-#{attrEvent.name}")
    span.attr('data-val', attr.value)
    span.find('.val').text(pimatic.pages.index.attrValueToText attr)
    return

  addRule: (rule) ->
    pimatic.rules[rule.id] = rule 
    li = $ $('#rule-template').html()
    li.attr('id', "rule-#{rule.id}")   
    li.find('a').data('rule-id', rule.id)
    li.find('.condition').text(rule.condition)
    li.find('.action').text(rule.action)
    unless rule.active
      li.addClass('deactivated')
    li.addClass 'rule'
    li.find("a").before $('<div class="ui-icon-alt handle">
      <div class="ui-icon ui-icon-bars"></div>
    </div>')

    pimatic.pages.index.addRuleDragslide(rule, li)

    $('#add-rule').before li
    $('#rules').listview('refresh') if pimatic.pages.index.pageCreated
    return

  addRuleDragslide: (rule, li) =>
    action = null

    showDragMessage = (msg) =>
      $('.drag-message')
      .text(msg)
      .css(
        top: li.position().top
        height: li.outerHeight()
        'line-height': li.outerHeight() + "px"
      ).fadeIn(500)


    li.draggable(
      axis: "x"
      revert: true
      handle: 'a'
      zIndex: 100
      scroll: false
      revertDuration: 200
      start: => 
      drag: ( event, ui ) => 
        # offset of the helper is 15 at start
        offsetX = ui.offset.left-15
        if offsetX < -120
          unless action is "deactivate"
            showDragMessage(__('deactivate rule')).addClass('deactivate').removeClass('activate')
            action = "deactivate"
        else if offsetX > 120
          unless action is "activate"
            showDragMessage(__('activate rule')).addClass('activate').removeClass('deactivate')
            action = "activate"
        else
          if action?
            $('.drag-message').fadeOut(500)
            action = null

      stop: => 
        $('.drag-message').text('').fadeOut().removeClass('activate').removeClass('deactivate')
        if action?
          pimatic.loading "saveactivate", "show", text: __(action)
          $.ajax("/api/rule/#{rule.id}/#{action}",
            global: false
          ).always( ->
            pimatic.loading "saveactivate", "hide"
          ).done(ajaxShowToast).fail(ajaxAlertFail)
    )

    ###
      Some realy dirty hacks to allow vertival scralling
    ###
    if $.ui.mouse.prototype._touchStart?
      uiDraggable = li.data('uiDraggable')

      # Capture the last mousedown/touchstart event
      lastVmouseDown = null
      li.on('vmousedown', (event) =>
        if $(event.target).parent('.handle').length then return
        lastVmouseDown = event
      )

      uiDraggable._isDragging = no
      # If the mouse
      li.on('vmousemove', (event) =>
        if $(event.target).parent('.handle').length then return
        unless lastVmouseDown is null
          deltaX = Math.abs(event.pageX - lastVmouseDown.pageX)
          deltaY = Math.abs(event.pageY - lastVmouseDown.pageY)
          # detect horizontal drag
          if deltaX > deltaY and deltaX > 5 and not uiDraggable._isDragging
            # https://code.google.com/p/android/issues/detail?id=19827
            event.originalEvent.preventDefault();
            originalEvent = lastVmouseDown.originalEvent
            uiDraggable._isDragging = yes
            $.ui.mouse.prototype._touchStart.apply(
              uiDraggable, [originalEvent]
            )
            lastVmouseDown = null
      )

  updateRule: (rule) ->
    pimatic.rules[rule.id] = rule 
    li = $("\#rule-#{rule.id}")   
    li.find('.condition').text(rule.condition)
    li.find('.action').text(rule.action)
    if rule.active
      li.removeClass('deactivated')
    else
      li.addClass('deactivated')
    $('#rules').listview('refresh') if pimatic.pages.index.pageCreated
    return

  removeRule: (rule) ->
    delete pimatic.rules[rule.id]
    $("\#rule-#{rule.id}").remove()
    $('#rules').listview('refresh') if pimatic.pages.index.pageCreated
    return

  reorderRules: (order) ->
    #detactch all items
    rules = $('#rules .rule')
    rules.detach()
    for o in order
      # find the matching item
      for r,i in rules
        r = $ r
        # reappend it
        if r.find('a').data('rule-id') is o
          r.insertBefore('#add-rule')
          rules.splice(i, 1)
          break

  fixScrollOverDraggableRule: ->

    _touchStart = $.ui.mouse.prototype._touchStart
    if _touchStart?
      $.ui.mouse.prototype._touchStart = (event) ->
        # Just alter behavior if the event is triggered on an draggable
        if this._isDragging?
          if this._isDragging is no
            # we are not dragging so allow scrolling
            return
        _touchStart.apply(this, [event]) 

      _touchMove = $.ui.mouse.prototype._touchMove
      $.ui.mouse.prototype._touchMove = (event) ->
        if this._isDragging?
          unless this._isDragging is yes
            # discard the event to not prevent defaults
            return
        _touchMove.apply(this, [event]) 

      _touchEnd = $.ui.mouse.prototype._touchEnd
      $.ui.mouse.prototype._touchEnd = (event) ->
        if this._isDragging?
          # stop dragging
          this._isDragging = no
        _touchEnd.apply(this, [event]) 
