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
        }
    ]
    onselect = [0, m, "AddAccount", "ClearHistory", "GeneralSettings", "RedditSettings", "About"]

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

    screen.AddHeaderText("About the channel")
    screen.AddParagraph("The channel is an open source channel developed by Protuhj, based on the original channel by Utmost Solutions, which was based on the Roku YouTube Channel by Jeston Tigchon. Source code of the channel can be found at https://github.com/Protuhj/myvideobuzz.  This channel is not affiliated with Google, YouTube, Reddit, or Utmost Solutions.")
    screen.AddParagraph("Version 1.7")
    screen.AddButton(1, "Back")
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

Function LoadConstants() as Object
    this = {}
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


    return this
End Function
