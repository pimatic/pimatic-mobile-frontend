# log-page
# ---------


$(document).on "pageinit", '#log', (event) ->
  $.get("/api/messages")
    .done( (data) ->
      for entry in data.messages
        pimatic.pages.log.addLogMessage entry
      $('#log-messages').listview('refresh') 
      pimatic.socket.on 'log', (entry) -> 
        pimatic.pages.log.addLogMessage entry
        $('#log-messages').listview('refresh') 
    ).fail(ajaxAlertFail)

  $('#log').on "click", '#clear-log', (event, ui) ->
    $.get("/clear-log")
      .done( ->
        $('#log-messages').empty()
        $('#log-messages').listview('refresh') 
        pimatic.errorCount = 0
        pimatic.pages.index.updateErrorCount()
      ).fail(ajaxAlertFail)
  return

pimatic.pages.log =
  lastEntry: null
  addLogMessage: (entry) ->
    li = $ $('#log-message-template').html()
    li.find('.level').text(entry.level).addClass(entry.level)
    li.find('.msg').text(entry.msg)
    lastDate = pimatic.pages.log.lastEntry?.time.substring(0, 10)
    newDate = entry.time.substring(0, 10)
    li.find('.time').text(
      (if lastDate isnt newDate then entry.time else entry.time.substring 11, 19) + " "
    )
    pimatic.pages.log.lastEntry = entry
    $('#log-messages').append li
    return