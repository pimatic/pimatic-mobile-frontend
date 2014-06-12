# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", '#groups-page', tc (event) ->

  class GroupsViewModel

    enabledEditing: ko.observable(no)
    isSortingGroups: ko.observable(no)

    constructor: () ->
      @groups = pimatic.groups

      @groupsListViewRefresh = ko.computed( tc =>
        @groups()
        @isSortingGroups()
        @enabledEditing()
        pimatic.try( => $('#groups').listview('refresh').addClass("dark-background") )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

    afterRenderGroup: (elements, group) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())

    onGroupsSorted: (group, eleBefore, eleAfter) =>
      groupOrder = []
      unless eleBefore?
        groupOrder.push group.id 
      for g in @groups()
        if g is group then continue
        groupOrder.push(g.id)
        if eleBefore? and g is eleBefore
          groupOrder.push(group.id)
      pimatic.client.rest.updateGroupOrder({groupOrder})
      .done(ajaxShowToast)
      .fail(ajaxAlertFail)
  
    onDropGroupOnTrash: (group) ->
      really = confirm(__("Do you really want to delete the %s group?", group.name()))
      if really then (doDeletion = =>
          pimatic.loading "deletegroup", "show", text: __('Saving')
          pimatic.client.rest.removeGroup(groupId: group.id).done( (data) =>
            if data.success
              @groups.remove(group)
          ).always( => 
            pimatic.loading "deletegroup", "hide"
          ).done(ajaxShowToast).fail(ajaxAlertFail)
        )()

    onAddGroupClicked: ->
      editGroupPage = pimatic.pages.editGroup
      editGroupPage.resetFields()
      editGroupPage.action('add')
      return true

    onEditGroupClicked: (group)->
      editGroupPage = pimatic.pages.editGroup
      editGroupPage.action('update')
      editGroupPage.groupId(group.id)
      editGroupPage.groupName(group.name())
      return true

  pimatic.pages.groups = groupsPage = new GroupsViewModel()

)

$(document).on("pagecreate", '#groups-page', tc (event) ->
  groupsPage = pimatic.pages.groups
  try
    ko.applyBindings(groupsPage, $('#groups-page')[0])
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $("#groups .handle").disableSelection()
  return
)

$(document).on("pagebeforeshow", '#groups-page', tc (event) ->
  pimatic.try( => $('#groups').listview('refresh').addClass("dark-background") )
)






