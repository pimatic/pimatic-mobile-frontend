# index-page
# ----------

$(document).on "pagecreate", '#index', (event) ->
  pimatic.pages.index.loadData()

  pimatic.socket.on "device-attribute", (attrEvent) -> 
    pimatic.pages.index.updateDeviceAttribute attrEvent
    if attrEvent.name is "state"
      value = if attrEvent.value then "on" else "off" 
      $("#flip-#{attrEvent.id}").val(value).slider('refresh')
    if attrEvent.name is "dimlevel"
      $("#slider-#{attrEvent.id}").val(value).slider('refresh')

  pimatic.socket.on "rule-add", (rule) -> pimatic.pages.index.addRule rule
  pimatic.socket.on "rule-update", (rule) -> pimatic.pages.index.updateRule rule
  pimatic.socket.on "rule-remove", (rule) -> pimatic.pages.index.removeRule rule
  pimatic.socket.on "item-add", (item) -> pimatic.pages.index.addItem item
  

  $('#index #items').on "change", ".switch", (event, ui) ->
    ele = $(this)
    val = ele.val()
    deviceId = ele.data('device-id')
    deviceAction = if val is 'on' then 'turnOn' else 'turnOff'
    $.get("/api/device/#{deviceId}/#{deviceAction}")
      .done(ajaxShowToast)
      .fail( ->
        ele.val(if val is 'on' then 'off' else 'on').slider('refresh')
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
      .fail( => ele.val(sliderValBefore).slider('refresh') )
      .fail(ajaxAlertFail)
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
      $.post "update-order", order: order
  )

  $("#items .handle").disableSelection()

  $("#delete-item").droppable(
    accept: "li.sortable"
    hoverClass: "ui-state-hover"
    drop: (ev, ui) ->
      item = {
        id: ui.draggable.data('item-id')
        type: ui.draggable.data('item-type')
      }
      $.post 'remove-item', item: item
      if item.type is 'device'
        delete pimatic.devices[item.id]
      ui.draggable.remove()
  )
  return

pimatic.pages.index =
  loading: no

  loadData: ->
    # already loading?
    if pimatic.pages.index.loading then return
    pimatic.pages.index.loading = yes
    $.get("/data.json")
      .done( (data) ->
        pimatic.devices = []
        pimatic.rules = []
        $('#items .item').remove()
        pimatic.pages.index.addItem(item) for item in data.items
        $('#rules .rule').remove()
        pimatic.pages.index.addRule(rule) for rule in data.rules
        pimatic.errorCount = data.errorCount
        pimatic.pages.index.updateErrorCount()
        pimatic.pages.index.loading = no
      ) #.fail(ajaxAlertFail)
    return

  updateErrorCount: ->
    if $('#error-count').find('.ui-btn-text').length > 0
      $('#error-count').find('.ui-btn-text').text(pimatic.errorCount)
      try
        $('#error-count').button('refresh')
      catch e
        # ignore: Uncaught Error: cannot call methods on button prior 
        # to initialization; attempted to call method 'refresh' 
    else
      $('#error-count').text(pimatic.errorCount)
    if pimatic.errorCount is 0 then $('#error-count').hide()
    else $('#error-count').show()
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
      else pimatic.pages.index.buildDevice(item)
    li.data('item-type', item.type)
    li.data('item-id', item.id)
    li.addClass 'item'
    $('#add-a-item').before li
    li.find("label").before $('<div class="ui-icon-alt handle">
      <div class="ui-icon ui-icon-bars"></div>
    </div>')
    $('#items').listview('refresh')

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

  attrValueToText: (attribute) ->
    if attribute.type is 'Boolean'
      unless attribute.labels? then return attribute.value?.toString()
      else if attribute.value is true then attribute.labels[0] 
      else if attribute.value is false then attribute.labels[1]
      else attribute.value?.toString()
    else return attribute.value?.toString()

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
    $('#add-rule').before li
    $('#rules').listview('refresh')
    return

  updateRule: (rule) ->
    pimatic.rules[rule.id] = rule 
    li = $("\#rule-#{rule.id}")   
    li.find('.condition').text(rule.condition)
    li.find('.action').text(rule.action)
    if rule.active
      li.removeClass('deactivated')
    else
      li.addClass('deactivated')
    $('#rules').listview('refresh')
    return

  removeRule: (rule) ->
    delete pimatic.rules[rule.id]
    $("\#rule-#{rule.id}").remove()
    $('#rules').listview('refresh')
    return
