
Function LoadYouTube() As Object
    ' global singleton
    return m.youtube
End Function

Function InitYouTube() As Object
    ' constructor
    this = CreateObject("roAssociativeArray")
    this.device_id = CreateObject("roDeviceInfo").GetDeviceUniqueId()
    this.protocol = "http"
    this.scope = this.protocol + "://gdata.youtube.com"
    this.prefix = this.scope + "/feeds/api"
    this.currentURL = ""
    this.searchLengthFilter = ""
    tmpLength = RegRead("length", "Search")
    if (tmpLength <> invalid) then
        this.searchLengthFilter = tmpLength
    end if
    this.searchDateFilter = ""
    tmpDate = RegRead("date", "Search")
    if (tmpDate <> invalid) then
        this.searchDateFilter = tmpDate
    end if

    ' Preferences object
    this.prefs = preferences()

    this.searchSort = ""
    tmpSort = RegRead("sort", "Search")
    if (tmpSort <> invalid) then
        this.searchSort = tmpSort
    end if

    this.CurrentPageTitle = ""
    this.screen       = invalid
    this.video        = invalid

    'API Calls
    this.ExecServerAPI = youtube_exec_api
    this.ExecBatchQuery = ExecBatchQuery_impl

    'Search
    this.SearchYouTube = youtube_search

    'User videos
    this.BrowseUserVideos = youtube_user_videos

    ' Playlists
    this.BrowseUserPlaylists = BrowseUserPlaylists_impl

    'related
    this.ShowRelatedVideos = youtube_related_videos

    'Videos
    this.DisplayVideoListFromVideoList = DisplayVideoListFromVideoList_impl
    this.DisplayVideoListFromMetadataList = DisplayVideoListFromMetadataList_impl
    this.FetchVideoList = FetchVideoList_impl
    this.VideoDetails = VideoDetails_impl
    this.newVideoListFromXML = youtube_new_video_list
    this.newVideoFromXML = youtube_new_video
    this.ReturnVideoList = ReturnVideoList_impl

    'Categories
    this.CategoriesListFromXML  = CategoriesListFromXML_impl

    this.BuildButtons = BuildButtons_impl

    'Settings
    this.BrowseSettings = youtube_browse_settings
    this.About = youtube_about
    this.AddAccount = youtube_add_account
    this.RedditSettings = EditRedditSettings
    this.ManageSubreddits = ManageSubreddits_impl
    this.ClearHistory = ClearHistory_impl

    ' History
    this.ShowHistory = ShowHistory_impl
    this.AddHistory = AddHistory_impl

    ' Initialize the history member, or else the ClearHistory function could fail below
    this.history = []

    ' Version of the history.
    ' Update when a new site is added, or when information stored in the registry might change
    this.HISTORY_VERSION = "1"
    regHistVer = RegRead( "HistoryVersion", "Settings" )
    if ( regHistVer = invalid OR regHistVer <> this.HISTORY_VERSION ) then
        print( "History version mismatch (clearing history), found: " + tostr( regHistVer ) + ", expected: " + this.HISTORY_VERSION )
        this.ClearHistory( false )
        RegWrite( "HistoryVersion", this.HISTORY_VERSION, "Settings" )
    end if

    ' TODO: Determine if this could be used for the reddit channel
    ' this.GetVideoDetails = GetVideoDetails_impl
    videosJSON = RegRead("videos", "history")
    this.historyLen = 0
    if ( videosJSON <> invalid AND isnonemptystr(videosJSON) ) then
        this.historyLen = Len(videosJSON)
        ' print("**** History string len: " + tostr(this.historyLen) + "****")
        this.history = ParseJson(videosJSON)
        if ( islist(this.history) = false ) then
            this.history = []
        end if
    end if

    ' LAN Videos related members
    this.dateObj = CreateObject( "roDateTime" )
    this.udp_socket = invalid
    this.mp_socket  = invalid
    this.udp_created = 0

    ' Regex found on the internets here: http://stackoverflow.com/questions/3452546/javascript-regex-how-to-get-youtube-video-id-from-url
    ' Pre-compile the YouTube video ID regex
    this.ytIDRegex = CreateObject("roRegex", "(?:youtube(?:-nocookie)?\.com/(?:[^/\n]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu\.be/)([^&?/ ]{11})", "igm")
    this.gfycatIDRegex = CreateObject( "roRegex", "(?:.*gfycat\.com\/)(\w*)\W*.*", "ig" )
    this.regexNewline = CreateObject( "roRegex", "\n", "ig" )
    this.regexTimestampHumanReadable = CreateObject( "roRegex", "\D+", "" )
    this.regexTimestampHours = CreateObject( "roRegex", "(\d+)h+", "i" )
    this.regexTimestampMinutes = CreateObject( "roRegex", "(\d+)m+", "i" )
    this.regexTimestampSeconds = CreateObject( "roRegex", "(\d+)s+", "i" )

    ' Should playlists be queried for their reversed order? Default is false
    this.reversed_playlist = false

    this.sleep_timer = -100
    return this
End Function

Function batch_request_xml( ids as Dynamic ) as String
    sQuote = Quote()
    returnVal = "<feed xmlns=" + sQuote + "http://www.w3.org/2005/Atom" + sQuote
    returnVal = returnVal + " xmlns:media=" + sQuote + "http://search.yahoo.com/mrss/" + sQuote
    returnVal = returnVal + " xmlns:batch=" + sQuote + "http://schemas.google.com/gdata/batch" + sQuote
    returnVal = returnVal + " xmlns:yt=" + sQuote + "http://gdata.youtube.com/schemas/2007" + sQuote + ">"
    returnVal = returnVal + "<batch:operation type=" + Quote() + "query" + Quote() + "/>"
    for each id in ids
        returnVal = returnVal + "<entry><id>http://gdata.youtube.com/feeds/api/videos/" + id + "</id></entry>"
    end for
    returnVal = returnVal + "</feed>"
    return returnVal
End Function

Sub ExecBatchQuery_impl( xmlContent as String )
    request = {}
    request.url_stub = "videos/batch"
    request.postdata = xmlContent
    m.FetchVideoList( request, "Videos Linked in Description", invalid )
End Sub

Function youtube_exec_api(request As Dynamic, username = "default" As Dynamic, extraParams = invalid as Dynamic) As Object
    'oa = Oauth()

    if (username = invalid) then
        username = ""
    else
        username = "users/" + username + "/"
    end if

    method = "GET"
    url_stub = request
    postdata = invalid
    headers = { }

    if (type(request) = "roAssociativeArray") then
        if (request.url_stub <> invalid) then
            url_stub = request.url_stub
        end if
        if (request.postdata <> invalid) then
            postdata = request.postdata
            method = "POST"
        end if
        if (request.headers <> invalid) then
            headers = request.headers
        end if
        if (request.method <> invalid) then
            method = request.method
        end if
    end if

    ' Cache the current URL for refresh operations
    m.currentURL = url_stub

    if (Instr(0, url_stub, "http://") OR Instr(0, url_stub, "https://")) then
        http = NewHttp(url_stub)
    else
        http = NewHttp(m.prefix + "/" + username + url_stub)
    end if

    http.method = method
    http.AddParam("v","2","urlParams")
    if ( islist( extraParams ) ) then
         for each e in extraParams
            http.AddParam( e.name, e.value )
         next
    end if
    'oa.sign(http,true)

    'print "----------------------------------"
    if ( isstr( request ) AND Instr( 1, request, "pkg:/" ) > 0 ) then
        rsp = ReadAsciiFile(request)
    else if (postdata <> invalid) then
        rsp = http.PostFromStringWithTimeout(postdata, 10, headers)
        'print "postdata:",postdata
    else
        rsp = http.getToStringWithTimeout(10, headers)
    end if


    'print "----------------------------------"
    'print rsp
    'print "----------------------------------"

    xml = ParseXML(rsp)

    returnObj = CreateObject("roAssociativeArray")
    returnObj.xml = xml
    returnObj.status = http.status
    if ( isstr( request ) AND Instr( 1, request, "pkg:/" ) < 0 ) then
        returnObj.error = handleYoutubeError(returnObj)
    end if

    return returnObj
End Function

Function handleYoutubeError(rsp) As Dynamic
    ' Is there a status code? If not, return a connection error.
    if (rsp.status = invalid) then
        return ShowConnectionFailed()
    end if
    ' Don't check for errors if the response code was a 2xx or 3xx number
    if (int(rsp.status / 100) = 2 OR int(rsp.status / 100) = 3) then
        return ""
    end if

    if (not(isxmlelement(rsp.xml))) then
        return ShowErrorDialog("API return invalid. Try again later", "Bad response")
    end if

    error = rsp.xml.GetNamedElements("error")[0]
    if (error = invalid) then
        ' we got an unformatted HTML response with the error in the title
        error = rsp.xml.GetChildElements()[0].GetChildElements()[0].GetText()
    else
        error = error.GetNamedElements("internalReason")[0].GetText()
    end if

    ShowDialog1Button("Error", error, "OK", true)
    return error
End Function

'********************************************************************
' YouTube User uploads
'********************************************************************
Sub youtube_user_videos(username As String, userID As String)
    m.FetchVideoList( "users/" + userID + "/uploads?orderby=published&safeSearch=none", "Videos By " + username, invalid )
End Sub

'********************************************************************
' YouTube User Playlists
'********************************************************************
Sub BrowseUserPlaylists_impl(username As String, userID As String)
    m.FetchVideoList( "users/" + userID + "/playlists?max-results=50&safeSearch=none", username + "'s Playlists", invalid, {isPlaylist: true} )
End Sub

'********************************************************************
' YouTube Related Videos
'********************************************************************
Sub youtube_related_videos(video As Object)
    m.FetchVideoList( "videos/" + video["ID"] + "/related?v=2&safeSearch=none", "Related Videos", invalid )
End Sub

'********************************************************************
' YouTube Poster/Video List Utils
'********************************************************************
Sub FetchVideoList_impl(APIRequest As Dynamic, title As String, username As Dynamic, categoryData = invalid as Dynamic, message = "Loading..." as String)

    'fields = m.FieldsToInclude
    'if Instr(0, APIRequest, "?") = 0 then
    '    fields = "?"+Mid(fields, 2)
    'end if

    screen = uitkPreShowPosterMenu("flat-episodic-16x9", title)
    screen.showMessage(message)

    response = m.ExecServerAPI(APIRequest, username)
    if (response.status = 403) then
        ShowErrorDialog(title + " may be private, or unavailable at this time. Try again.", "403 Forbidden")
        return
    end if
    if (not(isxmlelement(response.xml))) then
        ShowConnectionFailed()
        return
    end if

    ' Everything is OK, display the list
    xml = response.xml
    if (categoryData <> invalid) then
        categoryData.categories = m.CategoriesListFromXML(xml.entry)
        'PrintAny(0, "categoryList:", categories)
        m.DisplayVideoListFromVideoList([], title, xml.link, screen, categoryData)
    else
        videos = m.newVideoListFromXML(xml.entry)
        m.DisplayVideoListFromVideoList(videos, title, xml.link, screen, invalid)
    end if
End Sub


Function ReturnVideoList_impl(APIRequest As Dynamic, title As String, username As Dynamic, additionalParams = invalid as Dynamic)
    xml = m.ExecServerAPI(APIRequest, username, additionalParams)["xml"]
    if (not(isxmlelement(xml))) then
        ShowConnectionFailed()
        return []
    end if

    videos = m.newVideoListFromXML(xml.entry)
    metadata = GetVideoMetaData(videos)

    if (xml.link <> invalid) then
        for each link in xml.link
            if (link@rel = "next") then
                metadata.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg"})
            else if (link@rel = "previous") then
                metadata.Unshift({shortDescriptionLine1: "Back", action: "prev", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg"})
            end if
        end for
    end if

    return metadata
End Function

Sub DisplayVideoListFromVideoList_impl(videos As Object, title As String, links=invalid, screen = invalid, categoryData = invalid as Dynamic, metadataFunc = GetVideoMetaData as Function)
    if (categoryData = invalid) then
        metadata = metadataFunc(videos)
    else
        metadata = videos
    end if
    m.DisplayVideoListFromMetadataList(metadata, title, links, screen, categoryData)
End Sub

Sub DisplayVideoListFromMetadataList_impl(metadata As Object, title As String, links=invalid, screen = invalid, categoryData = invalid)
    if (screen = invalid) then
        screen = uitkPreShowPosterMenu("flat-episodic-16x9", title)
        screen.showMessage("Loading...")
    end if
    previousTitle = m.CurrentPageTitle
    m.CurrentPageTitle = title

    if (categoryData <> invalid) then
        categoryList = CreateObject("roArray", 100, true)
        for each category in categoryData.categories
            categoryList.Push(category.title)
        next

        oncontent_callback = [categoryData.categories, m,
            function(categories, youtube, set_idx, reverseSort = false)
                'PrintAny(0, "category:", categories[set_idx])
                if (youtube <> invalid AND categories.Count() > 0) then
                    additionalParams = []
                    additionalParams.push( { name: "safeSearch", value: "none" } )
                    if ( reverseSort ) then
                        additionalParams.push( { name: "orderby", value: "reversedPosition" } )
                    end if

                    return youtube.ReturnVideoList( categories[set_idx].link, youtube.CurrentPageTitle, invalid, additionalParams )
                else
                    return []
                end if
            end function]

        onclick_callback = [categoryData.categories, m,
            function(categories, youtube, video, category_idx, set_idx)
                if (video[set_idx]["action"] <> invalid) then
                    additionalParams = []
                    additionalParams.push( { name: "safeSearch", value: "none" } )
                    return { isContentList: true, content: youtube.ReturnVideoList(video[set_idx]["pageURL"], youtube.CurrentPageTitle, invalid, additionalParams ) }
                else
                    vidIdx% = youtube.VideoDetails(video[set_idx], youtube.CurrentPageTitle, video, set_idx)
                    return { isContentList: false, content: video, vidIdx: vidIdx%}
                end if
            end function]
        uitkDoCategoryMenu( categoryList, screen, oncontent_callback, onclick_callback, onplay_callback, categoryData.isPlaylist )
    else if (metadata.Count() > 0) then
        for each link in links
            if (type(link) = "roXMLElement") then
                if (link@rel = "next") then
                    metadata.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg"})
                else if (link@rel = "previous") then
                    metadata.Unshift({shortDescriptionLine1: "Back", action: "prev", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg"})
                end if
            else if (type(link) = "roAssociativeArray") then
                if (link.type = "next") then
                    metadata.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: link.href, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg", func: link.func})
                else if (link.type = "previous") then
                    metadata.Unshift({shortDescriptionLine1: "Back", action: "prev", pageURL: link.href, HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg", func: link.func})
                end if
            end if
        end for

        onselect = [1, metadata, m,
            function(video, youtube, set_idx)
                retVal% = 0
                if (video[set_idx]["func"] <> invalid) then
                    video[set_idx]["func"](youtube, video[set_idx]["pageURL"])
                else if (video[set_idx]["action"] <> invalid) then
                    youtube.FetchVideoList(video[set_idx]["pageURL"], youtube.CurrentPageTitle, invalid)
                else
                    retVal% = youtube.VideoDetails(video[set_idx], youtube.CurrentPageTitle, video, set_idx)
                end if
                return retVal%
            end function]
        uitkDoPosterMenu(metadata, screen, onselect, onplay_callback)
    else
        uitkDoMessage("No videos found.", screen)
    end if
    m.CurrentPageTitle = previousTitle
End Sub

'********************************************************************
' Callback function for when the user hits the play button from the video list
' screen.
' @param theVideo the video metadata object that should be played.
'********************************************************************
Sub onplay_callback(theVideo as Object)
    result = video_get_qualities(theVideo)
    if (result = 0) then
        DisplayVideo(theVideo)
    end if
End Sub

'********************************************************************
' Creates the list of categories from the provided XML
' @param xmlList the XML to create the category list from.
' @return an roList, which will be sorted by the yt:unreadCount if the XML
'         represents a list of subscriptions.
'         each category has the following members:
'           title
'           link
'********************************************************************
Function CategoriesListFromXML_impl(xmlList As Object) As Object
    'print "CategoriesListFromXML_impl init"
    categoryList  = CreateObject("roList")
    for each record in xmlList
        ''printAny(0, "xmlList:", record)
        category        = CreateObject("roAssociativeArray")
        if (record.GetNamedElements("yt:username").Count() > 0) then
            category.title = record.GetNamedElements("yt:username").GetAttributes()["display"]
        else
            category.title = record.GetNamedElements("title").GetText()
        end if
        if (record.GetNamedElements("yt:channelId").Count() > 0) then
            category.link =  "http://gdata.youtube.com/feeds/api/users/" + validstr(record.GetNamedElements("yt:channelId").GetText()) + "/uploads?v=2&max-results=50&safeSearch=none"
        else
            category.link   = validstr(record.content@src)
        end if

        if (record.GetNamedElements("yt:unreadCount").Count() > 0) then
            category.unreadCount% = record.GetNamedElements("yt:unreadCount").GetText().toInt()
        else
            category.unreadCount% = 0
        end if
        ' print (category.title + " unreadCount: " + tostr(category.unreadCount%))

        if (isnullorempty(category.link)) then
            links = record.link
            for each link in links
                if (Instr(1, link@rel, "user.uploads") > 0) then
                    category.link = validstr(link@href) + "&max-results=50"
                end if
            next
        end if

        categoryList.Push(category)
    next
    Sort(categoryList, Function(obj as Object) as Integer
            return obj.unreadCount%
        End Function)
    return categoryList
End Function



'********************************************************************
' Creates a list of video metadata objects from the provided XML
' @param xmlList the XML to create the list of videos from
' @return an roList of video metadata objects
'********************************************************************
Function youtube_new_video_list(xmlList As Object) As Object
    'print "youtube_new_video_list init"
    videolist = CreateObject("roList")
    for each record in xmlList
        video = m.newVideoFromXML(record)
        videolist.Push(video)
    next
    return videolist
End Function

Function youtube_new_video(xml As Object) As Object
    video                   = CreateObject("roAssociativeArray")
    video["ID"]             = xml.GetNamedElements("media:group")[0].GetNamedElements("yt:videoid")[0].GetText()
    video["Author"]         = get_xml_author(xml)
    video["UserID"]         = xml.GetNamedElements("media:group")[0].GetNamedElements("yt:uploaderId")[0].GetText()
    video["Title"]          = xml.title[0].GetText()
    video["Category"]       = xml.GetNamedElements("media:group")[0].GetNamedElements("media:category")[0].GetText()
    video["Linked"]         = get_linked( xml )
    video["Description"]    = get_desc(xml)
    video["Length"]         = GetLength_impl(xml)
    video["UploadDate"]     = GetUploadDate_impl(xml)
    video["Rating"]         = get_xml_rating(xml)
    video["Thumb"]          = get_xml_thumb(xml)
    return video
End Function

Function GetVideoMetaData(videos As Object)
    metadata = []

    for each video in videos
        meta = CreateObject("roAssociativeArray")
        meta.ContentType = "movie"

        meta["ID"]                     = video["ID"]
        meta["Author"]                 = video["Author"]
        meta["TitleSeason"]            = video["Title"]
        meta["Title"]                  = video["Author"] + "  - " + get_length_as_human_readable(video["Length"])
        meta["Actors"]                 = meta["Author"]
        meta["FullDescription"]        = video["Description"]
        meta["Description"]            = Left( video["Description"], 300 )
        meta["Categories"]             = video["Category"]
        meta["StarRating"]             = video["Rating"]
        meta["ShortDescriptionLine1"]  = meta["TitleSeason"]
        meta["ShortDescriptionLine2"]  = meta["Title"]
        meta["SDPosterUrl"]            = video["Thumb"]
        meta["HDPosterUrl"]            = video["Thumb"]
        meta["Length"]                 = video["Length"].toInt()
        meta["UserID"]                 = video["UserID"]
        meta["ReleaseDate"]            = video["UploadDate"]
        meta["StreamFormat"]           = "mp4"
        meta["Live"]                   = false
        meta["Streams"]                = []
        meta["Linked"]                 = video["Linked"]
        meta["Source"]                 = video["Source"]
        meta["PlayStart"]              = 0
        meta["SwitchingStrategy"]      = "no-adaptation"
        meta["Source"]                 = "YouTube"

        metadata.Push(meta)
    end for

    return metadata
End Function
Function get_linked( xml as Object ) as Dynamic
    desc = xml.GetNamedElements("media:group")[0].GetNamedElements("media:description")
    if (desc.Count() > 0) then
        return MatchAll( LoadYouTube().ytIDRegex, desc[0].GetText() )
    end if
    return []
End Function

Function get_desc(xml as Object) As Dynamic
    desc = xml.GetNamedElements("media:group")[0].GetNamedElements("media:description")
    if (desc.Count() > 0) then
        return desc[0].GetText()
    end if
    return "No description provided"
End Function

'*******************************************
'  Returns the length of the video from the yt:duration element:
'  <yt:duration seconds=val>
'*******************************************
Function GetLength_impl(xml as Object) As Dynamic
    durations = xml.GetNamedElements("media:group")[0].GetNamedElements("yt:duration")
    if (durations.Count() > 0) then
        return durations.GetAttributes()["seconds"]
    end if
    return "0"
End Function

'*******************************************
'  Returns the date the video was uploaded, from the yt:uploaded element:
'  <yt:uploaded>val</yt:uploaded>
'*******************************************
Function GetUploadDate_impl(xml as Object) As Dynamic
    uploaded = xml.GetNamedElements("media:group")[0].GetNamedElements("yt:uploaded")
    if (uploaded.Count() > 0) then
        dateText = uploaded.GetText()
        'dateObj = CreateObject("roDateTime")
        ' The value from YouTube has a 'Z' at the end, we need to strip this off, or else
        ' FromISO8601String() can't parse the date properly
        'dateObj.FromISO8601String(Left(dateText, Len(dateText) - 1))
        'return tostr(dateObj.GetMonth()) + "/" + tostr(dateObj.GetDayOfMonth()) + "/" + tostr(dateObj.GetYear())
        return Left(dateText, 10)
    end if
    return ""
End Function

'*******************************************
'  Returns the length of the video in a human-friendly format
'  i.e. 3700 seconds becomes: 1h 1m 40s
'*******************************************
Function get_length_as_human_readable(length As Dynamic) As String
    if (type(length) = "roString") then
        len% = length.ToInt()
    else if (type(length) = "roInteger") then
        len% = length
    else
        return "Unknown"
    end if

    if ( len% > 0 ) then
        hours%   = FIX(len% / 3600)
        len% = len% - (hours% * 3600)
        minutes% = FIX(len% / 60)
        seconds% = len% MOD 60
        if ( hours% > 0 ) then
            return Stri(hours%) + "h" + Stri(minutes%) + "m"
        else
            return Stri(minutes%) + "m" + Stri(seconds%) + "s"
        end if
    else if ( len% = 0 ) then
        return "Live Stream"
    end if
    ' Default return
    return "Unknown"
End Function

'*******************************************
'  Returns the length of the video in seconds
'  i.e. 1h1m becomes 3660 seconds
'*******************************************
Function get_human_readable_as_length(length As Dynamic) As Integer
    len% = 0
    yt = LoadYouTube()
    hourMatches = yt.regexTimestampHours.Match( length )
    if ( hourMatches.Count() = 2 ) then
        len% = len% + (3600 * strtoi( hourMatches[1] ))
    end if

    minuteMatches = yt.regexTimestampMinutes.Match( length )
    if ( minuteMatches.Count() = 2 ) then
        len% = len% + (60 * strtoi( minuteMatches[1] ))
    end if

    secMatches = yt.regexTimestampSeconds.Match( length )
    if ( secMatches.Count() = 2 ) then
        len% = len% + strtoi( secMatches[1] )
    end if
    return len%
End Function

Function get_xml_author(xml as Object) As Dynamic
    credits = xml.GetNamedElements("media:group")[0].GetNamedElements("media:credit")
    if (credits.Count() > 0) then
        for each author in credits
            if (author.GetAttributes()["role"] = "uploader") then
                return author.GetAttributes()["yt:display"]
            end if
        end for
    end if
    return ""
End Function

Function get_xml_rating(xml as Object) As Dynamic
    if (xml.GetNamedElements("gd:rating").Count() > 0) then
        return Int(xml.GetNamedElements("gd:rating").GetAttributes()["average"].toFloat() * 20)
    end if
    return 0
End Function

Function get_xml_thumb(xml as Object) As Dynamic
    thumbs = xml.GetNamedElements("media:group")[0].GetNamedElements("media:thumbnail")
    if (thumbs.Count() > 0) then
        for each thumb in thumbs
            if (thumb.GetAttributes()["yt:name"] = "mqdefault") then
                return thumb.GetAttributes()["url"]
            end if
        end for
        return xml.GetNamedElements("media:group")[0].GetNamedElements("media:thumbnail")[0].GetAttributes()["url"]
    end if
    return "pkg:/images/no_thumb.jpg"
End Function


'********************************************************************
' YouTube video details roSpringboardScreen
'********************************************************************
Function VideoDetails_impl(theVideo As Object, breadcrumb As String, videos=invalid, idx=invalid) as Integer
    p = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(p)

    m.screen    = screen
    m.video     = theVideo
    screen.SetDescriptionStyle("movie")
    if (theVideo["StarRating"] = invalid) then
        screen.SetStaticRatingEnabled(false)
    end if
    vidCount = videos.Count()
    if ( vidCount > 1 ) then
        screen.AllowNavLeft(true)
        screen.AllowNavRight(true)
    end if
    screen.SetPosterStyle("rounded-rect-16x9-generic")
    screen.SetDisplayMode("zoom-to-fill")
    screen.SetBreadcrumbText(breadcrumb, "Video")

    buttons = m.BuildButtons()

    screen.SetContent(m.video)
    screen.Show()

    while (true)
        msg = wait(2000, screen.GetMessagePort())
        if (type(msg) = "roSpringboardScreenEvent") then
            if (msg.isScreenClosed()) then
                'print "Closing springboard screen"
                exit while
            else if (msg.isButtonPressed()) then
                'print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
                if (msg.GetIndex() = 0) then ' Play/Resume
                    result = video_get_qualities(m.video)
                    if (result = 0) then
                        DisplayVideo(m.video)
                        buttons = m.BuildButtons()
                    end if
                else if (msg.GetIndex() = 1) then ' Play All
                    for i = idx to vidCount - 1  Step +1
                        selectedVideo = videos[i]
                        if ( selectedVideo["action"] = invalid )
                            result = video_get_qualities(selectedVideo)
                            if (result = 0) then
                                ret = DisplayVideo(selectedVideo)
                                m.video = videos[i]
                                buttons = m.BuildButtons()
                                screen.SetContent( m.video )
                                idx = i
                                if (ret > 0) then
                                    Exit For
                                end if
                            end if
                        end if
                    end for
                else if (msg.GetIndex() = 2) then
                    m.ShowRelatedVideos(m.video)
                else if (msg.GetIndex() = 3) then
                    m.BrowseUserVideos(m.video["Author"], m.video["UserID"])
                else if (msg.GetIndex() = 4) then
                    m.BrowseUserPlaylists(m.video["Author"], m.video["UserID"])
                else if (msg.GetIndex() = 5) then ' Play from beginning
                    m.video["PlayStart"] = 0
                    result = video_get_qualities(m.video)
                    if (result = 0) then
                        DisplayVideo(m.video)
                        buttons = m.BuildButtons()
                    end if
                else if (msg.GetIndex() = 6) then ' Linked videos
                    m.ExecBatchQuery( batch_request_xml( m.video["Linked"] ) )
                end if
            else if ( msg.isRemoteKeyPressed() ) then
                if ( msg.GetIndex() = 4 AND vidCount > 1 ) then  ' left arrow
                    idx = idx - 1
                    ' Check to see if the first video is an 'Action' button
                    if ( (idx < 0) OR (idx = 0 AND videos[idx]["action"] <> invalid) ) then
                        ' Set index to last video
                        idx = vidCount - 1
                    end if
                    ' Now check to see if the last video is an 'Action' button
                    if ( idx = vidCount - 1 AND videos[idx]["action"] <> invalid ) then
                        ' Last video is the 'next' video link, so move the index one more to the left
                         idx = idx - 1
                    end if
                    m.video = videos[idx]
                    buttons = m.BuildButtons()
                    screen.SetContent( m.video )
                else if ( msg.GetIndex() = 5 AND vidCount > 1 ) then ' right arrow
                    idx = idx + 1
                    ' Check to see if the last video is an "Action" button
                    if ( (idx = vidCount) OR (idx = vidCount - 1 AND videos[idx]["action"] <> invalid) ) then
                        ' Last video is the 'next' video link
                        idx = 0
                    end if
                    ' Now check to see if the first video is an 'Action' button
                    if ( idx = 0 AND videos[idx]["action"] <> invalid ) then
                        ' First video is the 'Back' video link, so move the index one more to the right
                         idx = idx + 1
                    end if
                    m.video = videos[idx]
                    buttons = m.BuildButtons()
                    screen.SetContent( m.video )
                end if
            else if ( msg.isButtonInfo() ) then
                while ( VListOptionDialog( false, m.video ) = 1 )
                end while
            else
                'print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        else if (msg = invalid) then
            CheckForMCast()
        end If
    end while
    return idx
End Function

'********************************************************************
' Helper function to build the list of buttons on the springboard
' @return an roAssociativeArray of the buttons
'********************************************************************
Function BuildButtons_impl() as Object
    m.screen.ClearButtons()
    buttons = CreateObject("roAssociativeArray")
    resumeEnabled = false
    if (m.video["Live"] = false AND m.video["PlayStart"] > 0) then
        resumeEnabled = true
        buttons["resume"]         = m.screen.AddButton(0, "Resume")
        buttons["restart"]        = m.screen.AddButton(5, "Play from beginning")
    else
        buttons["play"]           = m.screen.AddButton(0, "Play")
    end if
    buttons["play_all"]     = m.screen.AddButton(1, "Play All")
    if (m.video["Author"] <> invalid) then
        ' Hide related videos if the Resume/Play from beginning options are enabled
        if (not(resumeEnabled)) then
            buttons["show_related"] = m.screen.AddButton(2, "Show Related Videos")
        end if
        buttons["more"]         = m.screen.AddButton(3, "More Videos By " + m.video["Author"])
        buttons["playlists"]    = m.screen.AddButton(4, "Show "+ m.video["Author"] + "'s playlists")
    end if
    if (m.video["Linked"] <> invalid AND m.video["Linked"].Count() > 0) then
        buttons["linked"]       = m.screen.AddButton(6, "Linked Videos")
    end if
    return buttons
End Function

'********************************************************************
' The video playback screen
'********************************************************************
Function DisplayVideo(content As Object)
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    video.SetPositionNotificationPeriod(5)

    yt = LoadYouTube()
    ' Need to add the SSL cert to the video screen if in https
    if ( content["SSL"] = true ) then
        video.SetCertificatesFile( "common:/certs/ca-bundle.crt" )
        video.SetCertificatesDepth( 3 )
        video.InitClientCertificates()
    end if
    video.SetContent(content)
    video.show()
    ret = -1
    while (true)
        msg = wait(0, video.GetMessagePort())
        if (type(msg) = "roVideoScreenEvent") then
            if (Instr(1, msg.getMessage(), "interrupted") > 0) then
                ret = 1
            end if
            if (msg.isScreenClosed()) then 'ScreenClosed event
                'print "Closing video screen"
                video.Close()
                exit while
            else if (msg.isRequestFailed()) then
                print "play failed: " ; msg.GetMessage()
                ShowErrorDialog( "Video playback failed", "Unknown Playback Error" )
            else if (msg.isPlaybackPosition()) then
                content["PlayStart"] = msg.GetIndex()
                if ( yt.sleep_timer <> -100 AND msg.GetIndex() <> 0 ) then
                    yt.sleep_timer = yt.sleep_timer - 5
                    if ( yt.sleep_timer < 0 ) then
                        print( "Sleepy time" )
                        yt.sleep_timer = -100
                        video.Close()
                        ' Set the return value so that 'Play All' won't continue if the sleep timer elapses
                        ret = 2
                        problem = ShowDialogNoButton( "Sleep Timer Expired", "" )
                        sleep( 3000 )
                        problem.Close()
                        exit while
                    end if
                end if
            else if (msg.isFullResult()) then
                content["PlayStart"] = 0
            else if (msg.isPartialResult()) then
                ' For plugin videos, the Length may not be available.
                if (content.Length <> invalid) then
                    ' If we're within 30 seconds of the end of the video, don't allow resume
                    if (content["PlayStart"] > (content["Length"] - 30)) then
                        content["PlayStart"] = 0
                    end if
                end if
                ' Else if the length isn't valid, always allow resume
            else
                'print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while
    ' Add the video to history
    yt.AddHistory(content)
    return ret
End Function

Function getYouTubeMP4Url(video as Object, timeout = 0 as Integer, loginCookie = "" as String) as Object
    video["Streams"].Clear()
    isSSL = false
    if (Left(LCase(video["ID"]), 4) = "http") then
        url = video["ID"]
        if ( Left( LCase( url ), 5) = "https" ) then
            isSSL = true
        end if
    else
        url = "http://www.youtube.com/get_video_info?el=detailpage&video_id=" + video["ID"]
    end if
    htmlString = ""
    port = CreateObject("roMessagePort")
    ut = CreateObject("roUrlTransfer")
    ut.SetPort(port)
    ut.AddHeader("User-Agent", "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0")
    ut.AddHeader("Cookie", loginCookie)
    if ( isSSL = true ) then
        ut.SetCertificatesFile( "common:/certs/ca-bundle.crt" )
        ut.SetCertificatesDepth( 3 )
        ut.InitClientCertificates()
    end if
    ut.SetUrl(url)
    if (ut.AsyncGetToString()) then
        while (true)
            msg = Wait(timeout, port)
            if (type(msg) = "roUrlEvent") then
                status = msg.GetResponseCode()
                if (status = 200) then
                    htmlString = msg.GetString()
                end if
                exit while
            else if (type(msg) = "Invalid") then
                ut.AsyncCancel()
                exit while
            end if
        end while
    end if
    video["SSL"] = isSSL

    urlEncodedRegex = CreateObject("roRegex", "url_encoded_fmt_stream_map=([^(" + Chr(34) + "|&|$)]*)", "ig")
    commaRegex = CreateObject("roRegex", "%2C", "ig")
    ampersandRegex = CreateObject("roRegex", "%26", "ig")
    equalsRegex = CreateObject("roRegex", "%3D", "ig")

    if ( video["Source"] = "GDrive" ) then
        urlEncodedRegex = CreateObject( "roRegex", Chr(34) + "url_encoded_fmt_stream_map" + Chr(34) + "\:" + Chr(34) + "([^(" + Chr(34) + "|&|$)]*)" + Chr(34), "ig" )
        commaRegex = CreateObject( "roRegex", ",", "g" )
        ampersandRegex = CreateObject( "roRegex", "\\u0026", "ig" )
        equalsRegex = CreateObject( "roRegex", "\\u003D", "ig" )
    end if

    urlEncodedFmtStreamMap = urlEncodedRegex.Match( htmlString )

    if (urlEncodedFmtStreamMap.Count() > 1) then
        if (not(strTrim(urlEncodedFmtStreamMap[1]) = "")) then
            commaSplit = commaRegex.Split( urlEncodedFmtStreamMap[1] )
            hasHD = false
            fullHD = false
            topQuality% = -1
            if ( m.prefs.VideoQuality.value = Constants().FORCE_LOWEST ) then
                topQuality% = 10000
            end if
            streamData = invalid
            for each commaItem in commaSplit
                'print("CommaItem: " + commaItem)
                pair = {itag: "", url: "", sig: ""}
                ampersandSplit = ampersandRegex.Split( commaItem )
                for each ampersandItem in ampersandSplit
                    'print("ampersandItem: " + ampersandItem)
                    equalsSplit = equalsRegex.Split( ampersandItem )
                    if (equalsSplit.Count() = 2) then
                        pair[equalsSplit [0]] = equalsSplit [1]
                    end if
                end for
                'printAA( pair )
                if (pair.url <> "" and Left(LCase(pair.url), 4) = "http") then
                    if (pair.sig <> "") then
                        signature = "&signature=" + pair.sig
                    else
                        signature = ""
                    end if
                    urlDecoded = ut.Unescape(ut.Unescape(pair.url + signature))
                    itag% = strtoi( pair.itag )
                    if ( itag% <> invalid AND ( itag% = 18 OR itag% = 22 OR itag% = 37 ) ) then
                        'printAA( pair )
                        'print "urlDecoded: " ; urlDecoded
                        ' Determined from here: http://en.wikipedia.org/wiki/YouTube#Quality_and_codecs
                        if ( m.prefs.VideoQuality.value <> Constants().NO_PREFERENCE ) then
                            print "Not filtering streams"
                            if ( itag% = 18 ) then
                                ' 18 is MP4 270p/360p H.264 at .5 Mbps video bitrate
                                video["Streams"].Push( {url: urlDecoded, bitrate: 512, quality: false, contentid: pair.itag} )
                            else if ( itag% = 22 ) then
                                ' 22 is MP4 720p H.264 at 2-2.9 Mbps video bitrate. I set the bitrate to the maximum, for best results.
                                video["Streams"].Push( {url: urlDecoded, bitrate: 2969, quality: true, contentid: pair.itag} )
                                hasHD = true
                            else if ( itag% = 37 ) then
                                ' 37 is MP4 1080p H.264 at 3-5.9 Mbps video bitrate. I set the bitrate to the maximum, for best results.
                                video["Streams"].Push( {url: urlDecoded, bitrate: 6041, quality: true, contentid: pair.itag } )
                                hasHD = true
                                fullHD = true
                            end if
                        else if ( ( m.prefs.VideoQuality.value = Constants().FORCE_HIGHEST AND itag% > topQuality% ) OR ( m.prefs.VideoQuality.value = Constants().FORCE_LOWEST AND itag% < topQuality% ) ) then
                            print "Found stream with itag: " ; pair.itag
                            if ( itag% = 18 ) then
                                ' 18 is MP4 270p/360p H.264 at .5 Mbps video bitrate
                                streamData = {url: urlDecoded, bitrate: 512, quality: false, contentid: pair.itag}
                                topQuality% = itag%
                            else if ( itag% = 22 ) then
                                ' 22 is MP4 720p H.264 at 2-2.9 Mbps video bitrate. I set the bitrate to the maximum, for best results.
                                streamData = {url: urlDecoded, bitrate: 2969, quality: true, contentid: pair.itag}
                                hasHD = true
                                topQuality% = itag%
                            else if ( itag% = 37 ) then
                                ' 37 is MP4 1080p H.264 at 3-5.9 Mbps video bitrate. I set the bitrate to the maximum, for best results.
                                streamData = {url: urlDecoded, bitrate: 6041, quality: true, contentid: pair.itag }
                                hasHD = true
                                fullHD = true
                                topQuality% = itag%
                            end if
                        end if
                    else
                        print "Tried to parse invalid itag value."
                    end if
                end if
            end for
            if ( streamData <> invalid ) then
                video["Streams"].Push( streamData )
            end if
            if (video["Streams"].Count() > 0) then
                video["Live"]          = false
                video["StreamFormat"]  = "mp4"
                video["HDBranded"] = hasHD
                video["IsHD"] = hasHD
                video["FullHD"] = fullHD
            end if
        else
            hlsUrl = CreateObject("roRegex", "hlsvp=([^(" + Chr(34) + "|&|$)]*)", "").Match(htmlString)
            if (hlsUrl.Count() > 1) then
                urlDecoded = ut.Unescape(ut.Unescape(ut.Unescape(hlsUrl[1])))
                'print "Found hlsVP: " ; urlDecoded
                video["Streams"].Clear()
                video["Live"]              = true
                ' Set the PlayStart sufficiently large so it starts at 'Live' position
                video["PlayStart"]        = 500000
                video["StreamFormat"]      = "hls"
                'video["SwitchingStrategy"] = "unaligned-segments"
                video["SwitchingStrategy"] = "full-adaptation"
                video["Streams"].Push({url: urlDecoded, bitrate: 0, quality: false, contentid: -1})
            end if

        end if
    else
        print ("Nothing in urlEncodedFmtStreamMap")
    end if
    return video["Streams"]
End Function

Function getGfycatMP4Url(video as Object, timeout = 0 as Integer, loginCookie = "" as String) as Object
    video["Streams"].Clear()

    if ( video["ID"] <> invalid ) then
        url = "http://gfycat.com/cajax/get/" + video["ID"]
        jsonString = ""
        port = CreateObject( "roMessagePort" )
        ut = CreateObject( "roUrlTransfer" )
        ut.SetPort( port )
        ut.AddHeader( "User-Agent", "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0" )
        ut.AddHeader( "Cookie", loginCookie )
        ut.SetUrl( url )
        if ( ut.AsyncGetToString() ) then
            while ( true )
                msg = Wait( timeout, port )
                if ( type(msg) = "roUrlEvent" ) then
                    status = msg.GetResponseCode()
                    if ( status = 200 ) then
                        jsonString = msg.GetString()
                        json = ParseJson( jsonString )
                        if (json <> invalid) then
                            video["Streams"].Push( {url: htmlDecode( json.gfyItem.mp4Url ), bitrate: 512, quality: false, contentid: video["ID"]} )
                            video["Live"]          = false
                            video["StreamFormat"]  = "mp4"
                        end if
                    end if
                    exit while
                else if ( type(msg) = "Invalid" ) then
                    ut.AsyncCancel()
                    exit while
                end if
            end while
        end if
    end if
    return video["Streams"]
end function

Function getLiveleakMP4Url(video as Object, timeout = 0 as Integer, loginCookie = "" as String) as Object
    video["Streams"].Clear()

    if ( video["URL"] <> invalid ) then
        liveleakMP4UrlRegex = CreateObject( "roRegex", "file\:\s\" + Quote() + "(.*)&ec_rate", "ig" )
        liveleakMP4HDUrlRegex = CreateObject( "roRegex", "hd_file_url\=(.*)\%26ec_rate", "ig" )
        url = video["URL"]
        port = CreateObject( "roMessagePort" )
        ut = CreateObject( "roUrlTransfer" )
        ut.SetPort( port )
        ut.AddHeader( "User-Agent", "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0" )
        ut.AddHeader( "Cookie", loginCookie )
        ut.SetUrl( url )
        if ( ut.AsyncGetToString() ) then
            while ( true )
                msg = Wait( timeout, port )
                if ( type(msg) = "roUrlEvent" ) then
                    status = msg.GetResponseCode()
                    if ( status = 200 ) then
                        responseString = msg.GetString()
                        matches = liveleakMP4UrlRegex.Match( responseString )
                        if ( matches <> invalid AND matches.Count() > 1 ) then
                            video["Streams"].Push( {url: URLDecode( htmlDecode( matches[1] ) ), bitrate: 512, quality: false, contentid: video["ID"]} )
                            video["Live"]          = false
                            video["StreamFormat"]  = "mp4"
                        end if

                        hdmatches = liveleakMP4HDUrlRegex.Match( responseString )
                        if ( hdmatches <> invalid AND hdmatches.Count() > 1 ) then
                            video["Streams"].Push( {url: URLDecode( htmlDecode( hdmatches[1] ) ), bitrate: 2969, quality: true, contentid: video["ID"]} )
                            video["Live"]          = false
                            video["StreamFormat"]  = "mp4"
                            video["HDBranded"] = true
                            video["IsHD"] = true
                        end if
                    end if
                    exit while
                else if ( type(msg) = "Invalid" ) then
                    ut.AsyncCancel()
                    exit while
                end if
            end while
        end if
    end if
    return video["Streams"]
end function

Function getVineMP4Url(video as Object, timeout = 0 as Integer, loginCookie = "" as String) as Object
    video["Streams"].Clear()

    if ( video["URL"] <> invalid ) then
        vineMP4UrlRegex = CreateObject( "roRegex", "<meta itemprop=" + Quote() + "contentURL" + Quote() + " content=" + Quote() + "(.*)" + Quote(), "ig" )
        url = video["URL"]
        isSSL = false
        if ( Left( LCase( url ), 5 ) = "https" ) then
            isSSL = true
        end if
        port = CreateObject( "roMessagePort" )
        ut = CreateObject( "roUrlTransfer" )
        ut.SetPort( port )
        ut.AddHeader( "User-Agent", "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0" )
        ut.AddHeader( "Cookie", loginCookie )
        if ( isSSL = true ) then
            ut.SetCertificatesFile( "common:/certs/ca-bundle.crt" )
            ut.SetCertificatesDepth( 3 )
            ut.InitClientCertificates()
        end if
        ut.SetUrl( url )
        if ( ut.AsyncGetToString() ) then
            while ( true )
                msg = Wait( timeout, port )
                if ( type(msg) = "roUrlEvent" ) then
                    status = msg.GetResponseCode()
                    if ( status = 200 ) then
                        responseString = msg.GetString()
                        matches = vineMP4UrlRegex.Match( responseString )
                        if ( matches <> invalid AND matches.Count() > 1 ) then
                            video["Streams"].Push( {url: URLDecode( htmlDecode( matches[1] ) ), bitrate: 512, quality: false, contentid: video["ID"]} )
                            video["Live"]          = false
                            video["StreamFormat"]  = "mp4"
                            video["SSL"] = isSSL
                        end if
                    end if
                    exit while
                else if ( type(msg) = "Invalid" ) then
                    ut.AsyncCancel()
                    exit while
                end if
            end while
        end if
    end if
    return video["Streams"]
end function


Function video_get_qualities(video as Object) As Integer
    if ( video <> invalid AND video["Streams"] <> invalid ) then
        source = video["Source"]
        if ( source = invalid OR source = "YouTube" ) then
            getYouTubeMP4Url( video )
        else if ( source = "GDrive" ) then
            getYouTubeMP4Url( video )
        else if ( source = "Gfycat" ) then
            getGfycatMP4Url( video )
        else if ( source = "LiveLeak" ) then
            getLiveleakMP4Url( video )
        else if ( source = "Vine" ) then
            getVineMP4Url( video )
        end if

        if ( video["Streams"].Count() > 0 ) then
            return 0
        end if
    else
        print( "Invalid argument to video_get_qualities" )
    end if
    problem = ShowDialogNoButton( "", "Having trouble finding a Roku-compatible stream..." )
    sleep( 3000 )
    problem.Close()
    return -1
End Function

'********************************************************************
' Shows Users Video History
'********************************************************************
Sub ShowHistory_impl()
    m.DisplayVideoListFromMetadataList(m.history, "History", invalid, invalid, invalid)
End Sub

'********************************************************************
' Adds Video to History
' Store more data, but less items 5.
' This makes it easier to view history videos, without querying YouTube for information
' It also allows us to use the history list for the LAN Videos feature
'********************************************************************
Sub AddHistory_impl(video as Object)
    if ( islist(m.history) = true ) then
        ' If the item already exists in the list, move it to the front
        j = 0
        k = -1
        for each vid in m.history
            if ( vid["ID"] = video["ID"] ) then
                k = j
                exit for
            end if
            j = j + 1
        end for

        if ( k <> -1 ) then
            m.history.delete(k)
        end If

    end if

    ' Add the video to the beginning of the history list
    m.history.Unshift(video)

    'Is it safe to assume that 5 items will be less than 16KB? Need to find how to check array size in bytes in brightscript
    while(m.history.Count() > 5)
        ' Remove the last item in the list
        m.history.Pop()
    end while

    ' Don't write the streams list to the registry
    tempStreams = video["Streams"]
    video["Streams"].Clear()

    ' Make sure all the existing history items' Streams array is cleared
    ' and all of the descriptions are truncated before storing to the registry
    descs = {}
    fullDescs = {}
    for each vid in m.history
        if ( islist( vid["Streams"] ) ) then
            vid["Streams"].Clear()
        else
            vid["Streams"] = []
        end if
        descs[vid["ID"]] = vid["Description"]
        fullDescs[vid["ID"]] = vid["FullDescription"]

        if ( Len(descs[vid["ID"]]) > 50 ) then
            ' Truncate the description field for storing in the registry
            vid["Description"] = Left(descs[vid["ID"]], 50) + "..."
        end if
        vid["FullDescription"] = ""
    end for

    historyString = m.regexNewline.ReplaceAll( SimpleJSONArray(m.history), "")
    m.historyLen = Len(historyString)
    ' print("**** History string len: " + tostr(m.historyLen) + "****")
    RegWrite("videos", historyString, "history")
    video["Streams"] = tempStreams
    ' Load the non-truncated descriptions
    for each vid in m.history
        vid["Description"] = descs[vid["ID"]]
        vid["FullDescription"] = fullDescs[vid["ID"]]
    end for
End Sub

'********************************************************************
' Queries YouTube for more details on a video
' Currently unused, but could be levied for the reddit channel.
'********************************************************************
'Function GetVideoDetails_impl(theVideo as Object) As Object
'    api = "videos/" + tostr(theVideo["ID"]) + "?v=2"
'    xml = m.ExecServerAPI(api, invalid)["xml"]
'    if (isxmlelement(xml)) then
'        video = m.newVideoFromXML(xml)
'        videos = CreateObject("roArray", 1, true)
'        videos.Push(video)
'        metadata = GetVideoMetaData(videos)
'        if (metadata <> invalid AND metadata.Count() > 0) then
'            metadata[0].["ID"] = theVideo["ID"]
'            theVideo = metadata[0]
'        end if
'    end if
'    return theVideo
'End Function
