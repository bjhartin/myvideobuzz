
'  uitkDoPosterMenu
'
'    Display "menu" items in a Poster Screen.
'
Library "v30/bslCore.brs"
Function uitkPreShowPosterMenu(ListStyle="flat-category" as String, breadA = "Home", breadB = invalid) As Object
    port=CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)

    if (breadA <> invalid and breadB <> invalid) then
        screen.SetBreadcrumbText(breadA, breadB)
    else if (breadA <> invalid and breadB = invalid) then
        screen.SetBreadcrumbText(breadA, "")
        screen.SetTitle(breadA)
    end if

    if (ListStyle = "" OR ListStyle = invalid) then
        ListStyle = "flat-category"
    end if

    screen.SetListStyle(ListStyle)
    screen.SetListDisplayMode("scale-to-fit")
    ' screen.SetListDisplayMode("zoom-to-fill")
    screen.Show()

    return screen
end function


Function uitkDoPosterMenu(posterdata, screen, onselect_callback = invalid, onplay_func = invalid) As Integer
    if (type(screen) <> "roPosterScreen") then
        'print "illegal type/value for screen passed to uitkDoPosterMenu()"
        return -1
    end if

    screen.SetContentList(posterdata)
    idx% = 0

    ' If the first item is a button, and the 2nd item isn't a button, select the 2nd item.
    if ( posterdata[0]["action"] <> invalid AND posterdata.Count() > 1 AND posterdata[1]["action"] = invalid ) then
        idx% = 1
        screen.SetFocusedListItem( idx% )
    end if

    while (true)
        msg = wait(2000, screen.GetMessagePort())

        'print "uitkDoPosterMenu | msg type = ";type(msg)
        if (type(msg) = "roPosterScreenEvent") then
            'print "event.GetType()=";msg.GetType(); " event.GetMessage()= "; msg.GetMessage()
            if (msg.isListItemSelected()) then
                if (onselect_callback <> invalid) then
                    selecttype = onselect_callback[0]
                    if (selecttype = 0) then
                        this = onselect_callback[1]
                        selected_callback = onselect_callback[msg.GetIndex() + 2]
                        if (islist(selected_callback)) then
                            f = selected_callback[0]
                            userdata1 = selected_callback[1]
                            userdata2 = selected_callback[2]
                            userdata3 = selected_callback[3]

                            if (userdata1 = invalid) then
                                this[f]()
                            else if (userdata2 = invalid) then
                                this[f](userdata1)
                            else if (userdata3 = invalid) then
                                this[f](userdata1, userdata2)
                            else
                                this[f](userdata1, userdata2, userdata3)
                            end if
                        else
                            if (selected_callback = "return") then
                                return msg.GetIndex()
                            else
                                this[selected_callback]()
                            end if
                        end if
                    else if (selecttype = 1) then
                        userdata1 = onselect_callback[1]
                        userdata2 = onselect_callback[2]
                        f = onselect_callback[3]
                        f(userdata1, userdata2, msg.GetIndex())
                    end if
                else
                    return msg.GetIndex()
                end if
            else if (msg.isScreenClosed()) then
                return -1
            else if (msg.isListItemFocused()) then
                idx% = msg.GetIndex()
            else if (msg.isRemoteKeyPressed()) then
                ' If the play button is pressed on the video list, and the onplay_func is valid, play the video
                if (onplay_func <> invalid ) then
                    if ( msg.GetIndex() = bslUniversalControlEventCodes().BUTTON_PLAY_PRESSED ) then
                        onplay_func( posterdata[idx%] )
                    else if ( msg.GetIndex() = bslUniversalControlEventCodes().BUTTON_INFO_PRESSED ) then
                        while ( VListOptionDialog( false, posterdata[idx%] ) = 1 )
                        end while
                    end if
                end if
            end if
        else if (msg = invalid) then
            CheckForMCast()
        end if
    end while
End Function


Function uitkPreShowListMenu(breadA=invalid, breadB=invalid) As Object
    port = CreateObject("roMessagePort")
    screen = CreateObject("roListScreen")
    screen.SetMessagePort(port)
    if (breadA <> invalid and breadB <> invalid) then
        screen.SetBreadcrumbText(breadA, breadB)
    end if
    'screen.SetListStyle("flat-category")
    'screen.SetListDisplayMode("best-fit")
    'screen.SetListDisplayMode("zoom-to-fill")
    screen.Show()

    return screen
end function

Sub uitkTextScreen( title as String, headerText as String, text as String )
    port = CreateObject( "roMessagePort" )
    screen = CreateObject( "roTextScreen" )
    screen.SetMessagePort( port )
    screen.SetTitle( title )
    screen.SetText( "Title: " + headerText + Chr(13) + Chr(13) + "Description:" + Chr(13) + text )
    screen.Show()

    while ( true )
        msg = wait( 2000, port )
        if ( type( msg ) = "roTextScreenEvent" ) then
            if ( msg.isScreenClosed() ) then
                exit while
            end if
        else if ( msg = invalid ) then
            CheckForMCast()
        end if
    end while
End Sub


Function uitkDoListMenu(posterdata, screen, onselect_callback=invalid) As Integer

    if (type(screen) <> "roListScreen") then
        'print "illegal type/value for screen passed to uitkDoListMenu()"
        return -1
    end if

    screen.SetContent(posterdata)

    while (true)
        msg = wait(2000, screen.GetMessagePort())

        if (type(msg) = "roListScreenEvent") then
            'print "event.GetType()=";msg.GetType(); " Event.GetMessage()= "; msg.GetMessage()
            if (msg.isListItemSelected()) then
                if (onselect_callback <> invalid) then
                    selecttype = onselect_callback[0]
                    if (selecttype = 0) then
                        this = onselect_callback[1]
                        selected_callback = onselect_callback[msg.GetIndex() + 2]
                        if (islist(selected_callback)) then
                            f = selected_callback[0]
                            userdata1 = selected_callback[1]
                            userdata2 = selected_callback[2]
                            userdata3 = selected_callback[3]

                            if (userdata1 = invalid) then
                                this[f]()
                            else if (userdata2 = invalid) then
                                this[f](userdata1)
                            else if (userdata3 = invalid) then
                                this[f](userdata1, userdata2)
                            else
                                this[f](userdata1, userdata2, userdata3)
                            end if
                        else
                            if (selected_callback = "return") then
                                return msg.GetIndex()
                            else
                                this[selected_callback]()
                            end if
                        end if
                    else if (selecttype = 1) then
                        userdata1=onselect_callback[1]
                        userdata2=onselect_callback[2]
                        f=onselect_callback[3]
                        f(userdata1, userdata2, msg.GetIndex())
                    end if
                else
                    return msg.GetIndex()
                end if
            else if (msg.isScreenClosed()) then
                return -1
            end if
        else if (msg = invalid) then
            CheckForMCast()
        end if
    end while
    return 0
End Function


Function uitkDoCategoryMenu(categoryList, screen, content_callback = invalid, onclick_callback = invalid, onplay_func = invalid, isPlaylist = false) As Integer
    'Set current category to first in list
    category_idx = 0
    contentlist = []
    m.youtube.reversed_playlist = false
    screen.SetListNames( categoryList )
    contentdata1 = content_callback[0]
    contentdata2 = content_callback[1]
    content_f = content_callback[2]

    contentlist = content_f( contentdata1, contentdata2, 0, m.youtube.reversed_playlist )

    if (contentlist.Count() = 0) then
        screen.SetContentList([])
        screen.clearmessage()
        screen.showmessage("No viewable content in this section")
    else
        screen.SetContentList(contentlist)
        screen.clearmessage()
    end if
    screen.Show()
    idx% = 0
    contentdata1 = invalid
    contentdata2 = invalid
    content_f = invalid
    ' Tracks when the category was selected
    category_time = CreateObject("roTimespan")
    ' Tracks the amount of time between CheckForMCast calls
    multicast_time = CreateObject("roTimespan")
    ' This flag is used to determine when a query to the server for category data
    ' should actually occur, rather than every time a category was selected
    awaiting_timeout = false
    ' Default the multicast timer
    multicast_time.Mark()
    buttonCodes = bslUniversalControlEventCodes()
    while (true)
        msg = wait(500, screen.GetMessagePort())
        if (type(msg) = "roPosterScreenEvent") then
            if (msg.isListFocused()) then
                ' This event occurs when the category header is selected
                category_idx = msg.GetIndex()
                contentdata1 = content_callback[0]
                contentdata2 = content_callback[1]
                content_f = content_callback[2]
                ' Track that a timeout is being awaited
                awaiting_timeout = true
                ' Mark the time that the category was selected
                category_time.Mark()
            else if (msg.isListItemSelected()) then
                ' This event occurs when a video is selected with the "Ok" button
                userdata1 = onclick_callback[0]
                userdata2 = onclick_callback[1]
                content_f = onclick_callback[2]

                ' Reset the awaiting_timeout flag if an item is clicked
                awaiting_timeout = false
                category_time.Mark()

                contentData = content_f(userdata1, userdata2, contentlist, category_idx, msg.GetIndex())
                ' Handles when the Back/Forward arrows are clicked
                if ( contentData.isContentList = true ) then
                    contentlist = contentData.content
                    if (contentlist.Count() <> 0) then
                        if ( contentlist[0]["action"] <> invalid AND contentlist.Count() > 1 ) then
                            screen.SetFocusedListItem(1)
                        else
                            screen.SetFocusedListItem(0)
                        end if
                        screen.SetContentList(contentlist)
                        screen.Show()
                        'screen.SetFocusedListItem(msg.GetIndex())
                    end if
                end if
            else if (msg.isListItemFocused()) then
                ' This event occurs when the user changes the selection of a video item
                idx% = msg.GetIndex()
            else if (msg.isScreenClosed()) then
                return -1
            else if (msg.isRemoteKeyPressed()) then
                ' If the play button is pressed on the video list, and the onplay_func is valid, play the video
                if (onplay_func <> invalid AND msg.GetIndex() = buttonCodes.BUTTON_PLAY_PRESSED) then
                    onplay_func(contentlist[idx%])
                else if ( awaiting_timeout = false AND isPlaylist = true AND msg.GetIndex() = buttonCodes.BUTTON_INFO_PRESSED ) then
                    reversePlaylist = m.youtube.reversed_playlist
                    while ( VListOptionDialog( true, contentlist[idx%] ) = 1 )
                    end while
                    if ( reversePlaylist <> m.youtube.reversed_playlist ) then
                        ' This calls the content callback
                        contentlist = content_callback[2]( content_callback[0], content_callback[1], category_idx, m.youtube.reversed_playlist )
                        if (contentlist.Count() = 0) then
                            screen.SetContentList([])
                            screen.clearmessage()
                            screen.showmessage("No viewable content in this section")
                        else
                            screen.SetContentList(contentlist)
                            screen.clearmessage()
                            screen.SetFocusedListItem(0)
                            screen.Show()
                        end if
                    end if
                else if ( awaiting_timeout = false AND isPlaylist = false AND msg.GetIndex() = buttonCodes.BUTTON_INFO_PRESSED ) then
                    while ( VListOptionDialog( false, contentlist[idx%] ) = 1 )
                    end while
                end if
            end if
        else if (msg = invalid) then
            ' This addresses the issue when trying to scroll quickly through the category list,
            ' previously, each category would queue a request to YouTube, and the user would have to wait when they
            ' reached their desired category for the correct video list to load (could be painful with a lot of categories)
            if (awaiting_timeout = true AND category_time.TotalMilliseconds() > 900) then
                awaiting_timeout = false
                ' Playlist changed, reset the reversed flag
                m.youtube.reversed_playlist = false
                ' This calls the content callback
                contentlist = content_f( contentdata1, contentdata2, category_idx, m.youtube.reversed_playlist )
                if (contentlist.Count() = 0) then
                    screen.SetContentList([])
                    screen.ShowMessage("No viewable content in this section")
                else
                    screen.SetContentList(contentlist)
                    screen.SetFocusedListItem(0)
                    idx% = 0
                end if
            else if (multicast_time.TotalSeconds() > 2) then
                ' Don't allow the CheckForMCast function to run too much due to the category query change
                multicast_time.Mark()
                CheckForMCast()
            end if
        end If
    end while
End Function

Sub uitkDoMessage(message, screen)
    screen.showMessage(message)
    while (true)
        msg = wait(0, screen.GetMessagePort())
        if (msg.isScreenClosed()) then
            return
        end if
    end while
End Sub

Function VListOptionDialog( showReverse as Boolean, videoObj as Object ) as Integer
    dialog = CreateObject( "roMessageDialog" )
    port = CreateObject( "roMessagePort" )
    dialog.SetMessagePort( port )
    dialog.SetTitle( "Playback Settings" )
    dialog.SetMenuTopLeft( true )
    updateVListDialogText( dialog, false, showReverse )
    dialog.EnableBackButton( true )
    if ( showReverse = true ) then
        reverseId = 1
        sleepId = 2
        doneId = 3
        detailsId = 4
        dialog.addButton( reverseId, "Reverse Playlist Order" )
    else
        reverseId = 0
        sleepId = 1
        doneId = 2
        detailsId = 3
    end if
    dialog.addButton( sleepId, "Set Sleep Timer" )
    dialog.addButton( detailsId, "View Full Description" )
    dialog.addButton( doneId, "Done")
    dialog.Show()
    while true
        dlgMsg = wait(2000, dialog.GetMessagePort())
        if (type(dlgMsg) = "roMessageDialogEvent") then
            if (dlgMsg.isButtonPressed()) then
                ' Handles the "Reverse Playlist Order" item
                if (dlgMsg.GetIndex() = reverseId) then
                    m.youtube.reversed_playlist = NOT( m.youtube.reversed_playlist )
                    updateVListDialogText( dialog, true, showReverse )
                    return 1 ' Re-open the options
                ' This will be for the sleep timer menu
                else if (dlgMsg.GetIndex() = sleepId) then
                    dialog.Close()
                    ret = SleepTimerClicked()
                    if (ret <> 0) then
                        m.youtube.sleep_timer = ret
                        updateVListDialogText( dialog, true, showReverse )
                    end if
                    return 1 ' Re-open the options
                else if ( dlgMsg.GetIndex() = detailsId ) then
                    dialog.Close()
                    uitkTextScreen( "Full Description", videoObj["TitleSeason"], videoObj["Description"] )
                    return 0
                else if (dlgMsg.GetIndex() = doneId) then
                    dialog.Close()
                    exit while
                end if
            else if (dlgMsg.isScreenClosed()) then
                dialog.Close()
                exit while
            else
                ' print ("Unhandled msg type")
                exit while
            end if
        else if (dlgMsg = invalid) then
            CheckForMCast()
        else
            ' print ("Unhandled msg: " + type(dlgMsg))
            exit while
        end if
    end while
    return 0
End Function

Sub updateVListDialogText( dialog as Object, isUpdate as Boolean, showReverseText as Boolean )
    reversedText = "No"
    sleepText = "Off"
    if ( m.youtube.reversed_playlist = true ) then
        reversedText = "Yes"
    end if
    if ( m.youtube.sleep_timer <> -100 ) then
        sleepText = get_length_as_human_readable( m.youtube.sleep_timer )
    end if
    dialogText = ""
    if ( showReverseText = true ) then
        dialogText = "Playlist Reversed: " + reversedText + chr(10)
    end if
    dialogText = dialogText + "Sleep Timer: " + sleepText
    if ( isUpdate = true ) then
        dialog.UpdateText( dialogText )
    else
        dialog.SetText( dialogText )
    end if
End Sub

Function SleepTimerClicked() as Integer
    dialog = CreateObject( "roMessageDialog" )
    port = CreateObject( "roMessagePort" )
    dialog.SetMessagePort( port )
    dialog.SetTitle( "Sleep Timer Settings" )
    dialog.SetMenuTopLeft( true )
    dialog.EnableBackButton( true )
    dialog.addButton( -1, "Off")
    dialog.addButton( 30, "30 minutes" )
    dialog.addButton( 45, "45 minutes" )
    dialog.addButton( 60, "60 minutes" )
    dialog.addButton( 75, "75 minutes" )
    dialog.addButton( 90, "90 minutes" )
    dialog.Show()
    retVal = 0
    while true
        dlgMsg = wait( 2000, dialog.GetMessagePort() )
        if ( type (dlgMsg ) = "roMessageDialogEvent" ) then
            if ( dlgMsg.isButtonPressed() ) then
                if ( dlgMsg.GetIndex() = -1 ) then
                    retVal = -100
                else
                    retVal = dlgMsg.GetIndex() * 60
                end if
                exit while
            else if ( dlgMsg.isScreenClosed() ) then
                exit while
            end if
        else if (dlgMsg = invalid) then
            CheckForMCast()
        end if
    end while
    dialog.Close()
    return retVal
End Function