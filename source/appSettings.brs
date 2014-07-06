'**************************************************
' @param prefData associative array with the following items:
'       prefName as String
'       prefDesc as String
'       prefDefault as Dynamic
'       preyKey  as String
'       prefType as String
'       enumType (Optional) as Dynamic
'**************************************************
Function createPref( prefData as Object ) as Object
    base = {}
    base.name       = prefData.prefName
    base.key        = prefData.prefKey
    base.value      = strtoi( firstValid( loadPrefValue( prefData.prefKey ), tostr( prefData.prefDefault ) ) )
    base.default    = prefData.prefDefault
    base.type       = prefData.prefType
    base.desc       = prefData.prefDesc
    base.values     = getEnumValuesForType( prefData.prefType, prefData.enumType )
    return base
End Function

Function LoadPreferences() as Object
    prefs = {}
    consts = getConstants()
    prefs.VideoQuality = createPref( { prefName: "Force Video Quality",
        prefDesc: "Should streams be filtered based on quality?",
        prefDefault: consts.NO_PREFERENCE,
        prefKey: consts.pVIDEO_QUALITY,
        prefType: "enum",
        enumType: consts.eVID_QUALITY
    })
    prefs.RedditEnabled = createPref( { prefName: "Enable Reddit",
        prefDesc: "Does the reddit icon appear on the home screen?",
        prefDefault: consts.ENABLED_VALUE,
        prefKey: consts.pREDDIT_ENABLED,
        prefType: "enum",
        enumType: consts.eENABLED_DISABLED
        })

    prefs.RedditFeed = createPref( { prefName: "Reddit Feed",
        prefDesc: "Which reddit feed to query?",
        prefDefault: consts.sRED_HOT,
        prefKey: consts.pREDDIT_FEED,
        prefType: "enum",
        enumType: consts.eREDDIT_QUERIES
        })

    prefs.RedditFilter = createPref( { prefName: "Reddit Time Filter",
        prefDesc: "Which time filter for the Top and Controversial feeds to apply?",
        prefDefault: consts.sRED_HOUR,
        prefKey: consts.pREDDIT_FILTER,
        prefType: "enum",
        enumType: consts.eREDDIT_FILTERS
        })

    prefs.getPrefData  = getPrefData_impl
    prefs.getPrefValue = getPrefValue_impl
    prefs.setPrefValue = setPrefValue_impl
    return prefs
End Function

Function getPrefValue_impl( key as String ) as Dynamic
    retVal = invalid
    if ( m[key] <> invalid ) then
        retVal = m[key].value
    end if
    return retVal
End Function

Sub setPrefValue_impl( key as String, value as Dynamic )
    retVal = invalid
    if ( m[key] <> invalid ) then
        m[key].value = value
        RegWrite( key, tostr( value ), "Preferences" )
    else
        RegDelete( key, "Preferences" )
    end if
End Sub

Function getPrefData_impl( key as String ) as Dynamic
    retVal = invalid
    if ( m[key] <> invalid ) then
        retVal = m[key]
    end if
    return retVal
End Function

Function loadPrefValue( key as String ) as Dynamic
    return RegRead( key, "Preferences" )
End Function

Sub youtube_browse_settings()
    screen = uitkPreShowPosterMenu("","Settings")
    settingmenu = [
        {
            ShortDescriptionLine1:"Add Account",
            ShortDescriptionLine2:"Add your YouTube account",
            HDPosterUrl:"pkg:/images/icon_key.jpg",
            SDPosterUrl:"pkg:/images/icon_key.jpg"
        },
        {
            ShortDescriptionLine1:"Clear History",
            ShortDescriptionLine2:"Clear your Video History - Current Size: " + tostr(m.historyLen) + " bytes",
            HDPosterUrl:"pkg:/images/ClearHistory.png",
            SDPosterUrl:"pkg:/images/ClearHistory.png"
        },
        {
            ShortDescriptionLine1:"General",
            ShortDescriptionLine2:"General Settings",
            HDPosterUrl:"pkg:/images/General_Settings.png",
            SDPosterUrl:"pkg:/images/General_Settings.png"
        },
        {
            ShortDescriptionLine1:"Reddit",
            ShortDescriptionLine2:"Settings for the reddit channel.",
            HDPosterUrl:"pkg:/images/reddit_beta.jpg",
            SDPosterUrl:"pkg:/images/reddit_beta.jpg"
        },
        {
            ShortDescriptionLine1:"About",
            ShortDescriptionLine2:"About the channel",
            HDPosterUrl:"pkg:/images/About.jpg",
            SDPosterUrl:"pkg:/images/About.jpg"
        },
        {
            ShortDescriptionLine1:"Check for an Update",
            ShortDescriptionLine2:"Check GitHub for an update to the channel.",
            HDPosterUrl:"pkg:/images/check_update.png",
            SDPosterUrl:"pkg:/images/check_update.png"
        }
    ]
    onselect = [0, m, "AddAccount", "ClearHistory", "GeneralSettings", "RedditSettings", "About", "UpdateCheck"]

    uitkDoPosterMenu( settingmenu, screen, onselect )
End Sub

Sub EditGeneralSettings()
    settingmenu = [
        {
            Title: "Video Quality",
            HDPosterUrl:"pkg:/images/Settings.jpg",
            SDPosterUrl:"pkg:/images/Settings.jpg",
            prefData: getPrefs().getPrefData( getConstants().pVIDEO_QUALITY )
        }
    ]

    uitkPreShowListMenu( m, settingmenu, "General Preferences", "Preferences", "General" )
End Sub

Sub youtube_add_account()
    screen = CreateObject("roKeyboardScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    screen.SetTitle("YouTube User Settings")

    ytusername = RegRead("YTUSERNAME1")
    if (ytusername <> invalid) then
        screen.SetText(ytusername)
    end if

    screen.SetDisplayText("Enter your YouTube User name (not email address)")
    screen.SetMaxLength(35)
    screen.AddButton(1, "Finished")
    screen.AddButton(2, "Help")
    screen.Show()

    while (true)
        msg = wait(0, screen.GetMessagePort())
        if (type(msg) = "roKeyboardScreenEvent") then
            if (msg.isScreenClosed()) then
                return
            else if (msg.isButtonPressed()) then
                if (msg.GetIndex() = 1) then
                    searchText = screen.GetText()
                    plxml = GetFeedXML("http://gdata.youtube.com/feeds/api/users/" + searchText + "/playlists?v=2&max-results=50")
                    if (plxml = invalid) then
                        ShowDialog1Button("Error", searchText + " is not a valid YouTube User Id. Please go to http://github.com/Protuhj/myvideobuzz to find your YouTube username.", "Ok")
                    else
                        RegWrite("YTUSERNAME1", searchText)
                        screen.Close()
                        ShowHomeScreen()
                        return
                    end if
                else
                    ShowDialog1Button("Help", "Go to http://github.com/Protuhj/myvideobuzz to find your YouTube username.", "Ok")
                end if
            end if
        end if
    end while
End Sub


Sub youtube_about()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")
    screen.SetMessagePort(port)

    screen.AddHeaderText( "About the channel" )
    screen.AddParagraph( "The channel is an open source channel developed by Protuhj, based on the original channel by Utmost Solutions, which was based on the Roku YouTube Channel by Jeston Tigchon. Source code of the channel can be found at https://github.com/Protuhj/myvideobuzz.  This channel is not affiliated with Google, YouTube, Reddit, or Utmost Solutions." )
    screen.AddParagraph( "Version " + getConstants().VERSION_STR )
    screen.AddButton( 1, "Back" )
    screen.Show()

    while (true)
        msg = wait(2000, screen.GetMessagePort())

        if (type(msg) = "roParagraphScreenEvent") then
            return
        else if (msg = invalid) then
            CheckForMCast()
        end if
    end while
End Sub

Sub UpdateCheck_impl()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")
    screen.SetMessagePort(port)
    dialog = ShowPleaseWait( "Checking for updates..." )
    screen.AddHeaderText("Update check")
    screen.AddButton(1, "Back")
    screen.Show()
    rsp = QueryForJson( "https://api.github.com/repos/Protuhj/myvideobuzz/releases" )
    dialog.Close()
    if ( rsp.json <> invalid ) then
        if ( isReleaseNewer( rsp.json[0].tag_name ) ) then
            screen.AddParagraph( "New version available: " + rsp.json[0].tag_name )
            if ( ShowDialog2Buttons( "Update Available", "A new update is available (" + rsp.json[0].tag_name + "), would you like to update the channel now?" + Chr(10) + "The channel will automatically restart if you do.", "Not Now", "Update" ) = 2 ) then
                DoUpdate( "https://github.com/Protuhj/myvideobuzz/releases/download/" + rsp.json[0].tag_name + "/" + rsp.json[0].assets[0].name )
            end if
        else
            screen.AddParagraph( "No New Releases Available" )
        end if
    end if
    while (true)
        msg = wait(2000, screen.GetMessagePort())

        if (type(msg) = "roParagraphScreenEvent") then
            return
        else if (msg = invalid) then
            CheckForMCast()
        end if
    end while
End Sub

Sub ClearHistory_impl( showDialog = true as Boolean )
    RegDelete( "videos", "history" )
    m.history.Clear()
    m.historyLen = 0
    if ( showDialog = true ) then
        ShowErrorDialog( "Your video history has been cleared.", "Clear History" )
    end if
End Sub

Function GetFeedXML(plurl As String) As Dynamic
        http = NewHttp(plurl)
        plrsp = http.GetToStringWithRetry()

        plxml = CreateObject("roXMLElement")
        if (not(plxml.Parse(plrsp))) then
            return invalid
        end if

        if (plxml.GetName() <> "feed") then
            return invalid
        end if

        if (not(islist(plxml.GetBody()))) then
            return invalid
        end if
        return plxml
End Function

Function getEnumValuesForType( prefType as String, enumType = invalid as Dynamic) as Object
    retVal = invalid
    if ( prefType = "bool" ) then
        retVal = [ "false", "true" ]
    else if ( prefType = "enum" ) then
        constants = getConstants()
        if ( enumType = invalid ) then
            print "Enum type required for getEnumValuesForType with prefType of enum"
        else if ( enumType = constants.eVID_QUALITY ) then
            retVal = [ "No Preference", "Force Highest", "Force Lowest" ]
        else if ( enumType = constants.eENABLED_DISABLED ) then
            retVal = [ "Enabled", "Disabled" ]
        else if ( enumType = constants.eREDDIT_QUERIES ) then
            retVal = [ "Hot", "New", "Rising", "Top", "Controversial" ]
        else if ( enumType = constants.eREDDIT_FILTERS ) then
            retVal = [ "This Hour", "Today", "This Week", "This Year", "All Time" ]
        else
            print "enum must have the enumType defined!"
        end if
    end if
    return retVal
End Function

Function getEnumValueForType( enumType as String, index as Integer ) as Object
    retVal = invalid
    constants = getConstants()
    if ( enumType = invalid ) then
        print "Enum type required for getEnumValueForType"
    else if ( enumType = constants.eVID_QUALITY ) then
        retVal = [ "No Preference", "Force Highest", "Force Lowest" ][index]
    else if ( enumType = constants.eENABLED_DISABLED ) then
        retVal = [ "Enabled", "Disabled" ][index]
    else if ( enumType = constants.eREDDIT_QUERIES ) then
        retVal = [ "Hot", "New", "Rising", "Top", "Controversial" ][index]
    else if ( enumType = constants.eREDDIT_FILTERS ) then
        retVal = [ "Hour", "Day", "Week", "Year", "All" ][index]
    else
        print "enum must have the enumType defined!"
    end if
    return retVal
End Function

Function isReleaseNewer( releaseVer as String ) as Boolean
    retVal = false
    constants = getConstants()
    vRegex = CreateObject( "roRegex", "v", "i" )
    strVersion = vRegex.ReplaceAll( releaseVer, "" )
    curVersionSplit = strTokenize( constants.VERSION_STR, "." )
    newVersionSplit = strTokenize( strVersion, "." )
    curVersionMajor = 0
    curVersionMinor = 0
    curVersionSub   = 0

    newVersionMajor = 0
    newVersionMinor = 0
    newVersionSub   = 0
    idx% = 0
    for each str in curVersionSplit
        val = firstValid( strtoi( str ), 0 )
        if ( idx% = 0 ) then
            curVersionMajor = val
        else if ( idx% = 1 ) then
            curVersionMinor = val
        else
            curVersionSub = val
        end if
        idx% = idx% + 1
    end for
    idx% = 0
    for each str in newVersionSplit
        val = firstValid( strtoi( str ), 0 )
        if ( idx% = 0 ) then
            newVersionMajor = val
        else if ( idx% = 1 ) then
            newVersionMinor = val
        else
            newVersionSub = val
        end if
        idx% = idx% + 1
    end for

    if ( newVersionMajor > curVersionMajor ) then
        retVal = true
    else if ( newVersionMajor = curVersionMajor ) then
        if ( newVersionMinor > curVersionMinor ) then
            retVal = true
        else if ( newVersionMinor = curVersionMinor ) then
            if ( newVersionSub > curVersionSub ) then
                retVal = true
            end if
        end if
    end if

    return retVal
End Function

Sub DoUpdate( strLocation as String )
    
    port = CreateObject( "roMessagePort" )
    log = CreateObject( "roSystemLog" )
    log.SetMessagePort( port )
    log.EnableType( "http.error" )
    log.EnableType( "http.connect" )
    ut = CreateObject("roUrlTransfer")
    ut.AddHeader( "User-Agent", "curl/7.33.0" )
    ut.SetPort( port )
    ut.SetCertificatesFile( "common:/certs/ca-bundle.crt" )
    ut.SetCertificatesDepth( 3 )
    ut.InitClientCertificates()
    'ut.SetUrl( "https://github.com/Protuhj/myvideobuzz/releases/download/v1.6/MyVideoBuzz_v1_6.zip" )
    ut.SetUrl( strLocation )
    fs = CreateObject( "roFileSystem" )
    ut2 = CreateObject( "roUrlTransfer" )
    ut2.SetPort( port ) 
    boundary$ = "------------------------5dc38edd8963db02"
    if ( ut.AsyncGetToFile("tmp:/temp.zip") = true ) then
        respCount = 0
        while ( true )
            msg = Wait( 10000, port )
            if ( type(msg) = "roUrlEvent" ) then
                respCount = respCount + 1
                ' print "Response received: " + msg.GetString()
                
                status = msg.GetResponseCode()
                print "received Status: " ; tostr( status )
                if ( status = 200 AND respCount < 2 ) then
                    if ( fs.Exists( "tmp:/temp.zip" ) = true ) then
                        print "File exists, size: " ; tostr( fs.Stat( "tmp:/temp.zip"  ).size )
                        ut2.SetUserAndPassword( "rokudev", "roku" )
                        IPs = createObject("roDeviceInfo").getIpAddrs()
                        IPs.reset()
                        ip = IPs[IPs.next()]
                        ut2.SetUrl( "http://" + ip + "/plugin_install" )
                       'ut2.SetUrl( "http://192.168.1.231:80/plugin_install" )
                       ' ut.AsyncGetToString()
                        ct = "multipart/form-data; boundary=" + boundary$
                        ut2.AddHeader("Content-Type", ct )
                        textBytes = CreateObject( "roByteArray" )
                        'PostString$ = boundary$ +  Chr(13) + Chr(10) + GetContentDisposition2( "Install" ) + boundary$ +  Chr(13) + Chr(10) + GetContentDisposition( "temp.zip" ) + bytes.ToBase64String()
                        PostString$ = boundary$ +  Chr(13) + Chr(10) + GetContentDisposition2( "Install" ) + boundary$ +  Chr(13) + Chr(10) + GetContentDisposition( "temp.zip" )
                        textBytes.FromAsciiString( PostString$ )
                        textBytes.WriteFile( "tmp:/tempText.req" )
                        bytes = CreateObject( "roByteArray" )
                        boundaryBytes = CreateObject( "roByteArray" )
                        boundaryBytes.FromAsciiString( Chr(13) + Chr(10) + boundary$ + "--" + Chr(13) + Chr(10) + Chr(13) + Chr(10) )
                        bytes.ReadFile( "tmp:/temp.zip" )
                        ret = bytes.AppendFile( "tmp:/tempText.req" )
                        print "Result Append: " ; tostr( ret )
                        ret = boundaryBytes.AppendFile( "tmp:/tempText.req" )
                        print "Result Append 2: " ; tostr( ret )
                        'ret = ut2.AsyncPostFromString( PostString$ )
                        'ut2.AddHeader("Content-Disposition", GetContentDisposition2( "Install", boundary$ ) )
                        'ut2.AddHeader("Content-Disposition", GetContentDisposition( "temp.zip" ) )
                        'ut2.AddHeader("Content-Type", "application/octet-stream")
                        ret = ut2.AsyncPostFromFile( "tmp:/tempText.req" )
                        'ret = ut2.AsyncPostFromString( "" )
                        print "Result: " ; tostr( ret )
                    end if
                else
                    exit while
                end if
            else if ( type(msg) = "Invalid" ) then
                print "timeout reached"
                if ( respCount = 1 ) then
                    ut2.AsyncCancel()
                end if
                exit while
            else if ( type(msg) = "roSystemLogEvent" ) then
                print "System log event"
                printAA( msg.GetInfo() )
            else
                print "Unknown type: " ; type(msg)
            end if
        end while
        print "Delete temp.zip succeeded: " ; tostr( fs.Delete( "tmp:/temp.zip" ) )
        print "Delete tempText.req succeeded: " ; tostr( fs.Delete( "tmp:/tempText.req" ) )
    else
        print "File doesn't exist"
    end if
    
End Sub

Function LoadConstants() as Object
    this = {}
    this.VERSION_STR       = "1.7.1"
    this.NO_PREFERENCE     = 0
    this.FORCE_HIGHEST     = 1
    this.FORCE_LOWEST      = 2
    this.FALSE_VALUE       = 0
    this.TRUE_VALUE        = 1
    this.ENABLED_VALUE     = 0
    this.DISABLED_VALUE    = 1
    ' Enumeration type constants
    this.eVID_QUALITY      = "vidQuality"
    this.eENABLED_DISABLED = "enabledDisabled"
    this.eREDDIT_QUERIES   = "redditQueryTypes"
    this.eREDDIT_FILTERS    = "redditFilterTypes"

    ' Property Keys
    this.pREDDIT_ENABLED    = "RedditEnabled"
    this.pVIDEO_QUALITY     = "VideoQuality"
    this.pREDDIT_FEED       = "RedditFeed"
    this.pREDDIT_FILTER     = "RedditFilter"

    ' Source strings
    this.sYOUTUBE           = "YouTube"
    this.sGOOGLE_DRIVE      = "GDrive"
    this.sVINE              = "Vine"
    this.sGFYCAT            = "Gfycat"
    this.sLIVELEAK          = "LiveLeak"

    ' Reddit Query Indices
    this.sRED_HOT           = 0
    this.sRED_NEW           = 1
    this.sRED_RISING        = 2
    this.sRED_TOP           = 3
    this.sRED_CONTROVERSIAL = 4

    ' Reddit Filter Indices
    this.sRED_HOUR          = 0
    this.sRED_TODAY         = 1
    this.sRED_WEEK          = 2
    this.sRED_YEAR          = 3
    this.sRED_ALL           = 4

    ' Success error codes
    this.ERR_NORMAL_END     = &hFC
    this.ERR_VALUE_RETURN   = &hE2

    return this
End Function
