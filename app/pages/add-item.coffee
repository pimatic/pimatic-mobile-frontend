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
              showToast __("Please enter a name")
            else
              $.get("/add-header/#{name}").done((result) =>
                showToast __("Header added")
              ).fail(ajaxAlertFail)




$(document).on "pageshow", '#add-item', (event) ->

  $.get("/api/devices")
    .done( (data) ->
      $('#device-items .item').remove()
      for d in data.devices
        li = $ $('#item-add-template').html()
        if devices[d.id]? 
          li.data('icon', 'check')
          li.addClass('added')
        li.find('label').text(d.name)
        li.data 'device-id', d.id
        li.addClass 'item'
        $('#device-items').append li
      $('#device-items').listview('refresh')
    ).fail(ajaxAlertFail)


