# add-item-page
# ----------

$(document).on "pageinit", '#add-item', (event) ->

  $('#device-items').on "click", 'li.item', ->
    li = $ this
    if li.hasClass 'added' then return
    deviceId = li.data('device-id')
    $.get("/add-device/#{deviceId}")
      .done( (data) ->
        li.data('icon', 'check')
        li.addClass('added')
        li.buttonMarkup({ icon: "check" })
      ).fail(ajaxAlertFail)
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
    return
  return

$(document).on "pageshow", '#add-item', (event) ->
  $.get("/api/devices")
    .done( (data) ->
      $('#device-items .item').remove()
      for d in data.devices
        li = $ $('#item-add-template').html()
        if pimatic.devices[d.id]? 
          li.data('icon', 'check')
          li.addClass('added')
        li.find('label').text(d.name)
        li.data 'device-id', d.id
        li.addClass 'item'
        $('#device-items').append li
      $('#device-items').listview('refresh')
    ).fail(ajaxAlertFail)
  return


