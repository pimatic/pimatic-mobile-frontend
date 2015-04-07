# edit-variable-page
# --------------

$(document).on("pagebeforecreate", (event) ->
  if pimatic.pages.editGroup? then return
  
  class EditGroupViewModel

    action: ko.observable('add')
    groupName: ko.observable('')
    groupId: ko.observable('')

    constructor: ->
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add New Group') else __('Edit Group'))
      )

      pimatic.autoFillId(@groupName, @groupId, @action)

    resetFields: () ->
      @groupName('')
      @groupId('')

    onSubmit: ->
      unless pimatic.isValidId(@groupId())
        alert __(pimatic.invalidIdMessage)
        return

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
        if data.success then $.mobile.changePage '#groups-page', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      really = confirm(__("Do you really want to delete the %s group?", @groupName()))
      if really
        pimatic.client.rest.removeGroup({groupId: @groupId()})
          .done( (data) ->
            if data.success then $.mobile.changePage '#groups-page', {transition: 'slide', reverse: true}   
            else alert data.error
          ).fail(ajaxAlertFail)
      return false

  try
    pimatic.pages.editGroup = new EditGroupViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagecreate", '#edit-group-page', (event) ->
  try
    ko.applyBindings(pimatic.pages.editGroup, $('#edit-group-page')[0])
  catch e
    TraceKit.report(e)
)


$(document).on("pagebeforeshow", '#edit-group-page', (event) ->
  editGroupPage = pimatic.pages.editGroup
  params = jQuery.mobile.pageParams
  jQuery.mobile.pageParams = {}
  if params?.action is "update"
    group = params.group
    editGroupPage.action('update')
    editGroupPage.groupId(group.id)
    editGroupPage.groupName(group.name())
  else
    editGroupPage.resetFields()
    editGroupPage.action('add')
  return
)
