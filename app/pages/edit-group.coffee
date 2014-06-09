# edit-variable-page
# --------------

$(document).on("pagebeforecreate", (event) ->
  if pimatic.pages.editGroup? then return
  
  class EditGroupViewModel

    action: ko.observable('add')
    groupName: ko.observable('')
    groupId: ko.observable('')

    constructor: ->
      @groupTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add New Group') else __('Edit Group'))
      )
    resetFields: () ->
      @groupName('')
      @groupId('')

    onSubmit: ->
      params = {
        groupId: @groupId()
        group: 
          name: @groupName()
      }

      (
        switch @action()
          when 'add' then pimatic.client.rest.addGroup(params)
          when 'update' then pimatic.client.rest.updateGroup(params)
          else throw new Error("Illegal devicegroup action: #{action()}")
      ).done( (data) ->
        if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      pimatic.client.rest.removeGroup({groupId: @groupId()})
        .done( (data) ->
          if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
          else alert data.error
        ).fail(ajaxAlertFail)
      return false

  try
    pimatic.pages.editGroup = new EditGroupViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagecreate", '#edit-devicepage', (event) ->
  try
    ko.applyBindings(pimatic.pages.editGroup, $('#edit-devicepage')[0])
  catch e
    TraceKit.report(e)
)


