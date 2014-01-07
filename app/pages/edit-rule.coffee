# edit-rule-page
# --------------

$(document).on "pageinit", '#edit-rule', (event) ->
  $('#edit-rule').on "submit", '#edit-rule-form', ->
    ruleId = $('#edit-rule-id').val()
    ruleCondition = $('#edit-rule-condition').val()
    ruleActions = $('#edit-rule-actions').val()
    ruleText = "if #{ruleCondition} then #{ruleActions}"
    ruleEnabled = $('#edit-rule-active').is(':checked')
    action = $('#edit-rule-form').data('action')
    $.post("/api/rule/#{ruleId}/#{action}", 
      rule: ruleText
      active: ruleEnabled
    ).done( (data) ->
        if data.success then $.mobile.changePage('#index',{transition: 'slide', reverse: true})    
        else alert data.error
      ).fail(ajaxAlertFail)
    return false

  $('#edit-rule').on "click", '#edit-rule-remove', ->
    ruleId = $('#edit-rule-id').val()
    $.get("/api/rule/#{ruleId}/remove")
      .done( (data) ->
        if data.success then $.mobile.changePage('#index',{transition: 'slide', reverse: true})    
        else alert data.error
      ).fail(ajaxAlertFail)
    return false

  $(document).on "pagebeforeshow", '#edit-rule', (event) ->
    $('#edit-rule-active').checkboxradio "refresh"
    action = $('#edit-rule-form').data('action')
    switch action
      when 'add'
        $('#edit-rule h3').text __('Edit rule')
        $('#edit-rule-id').textinput('enable')
        $('#edit-rule-advanced').hide()
      when 'update'
        $('#edit-rule h3').text __('Add new rule')
        $('#edit-rule-id').textinput('disable')
        $('#edit-rule-advanced').show()
