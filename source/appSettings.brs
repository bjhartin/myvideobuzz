
Function preferences() as Object
    prefs = {}
    prefs.VideoQuality = createPref( "Force Video Quality", "Should streams be filtered based on quality?", Constants().NO_PREFERENCE, firstValid( RegRead( "VideoQuality", "Settings" ), Constants().NO_PREFERENCE ), "enum", Constants().eVID_QUALITY )
    prefs.RedditEnabled = createPref( "Enable Reddit", "Does the reddit icon appear on the home screen?", Constants().ENABLED_VALUE, firstValid( RegRead("enabled", "reddit"), Constants().ENABLED_VALUE ), "enum", Constants().eENABLED_DISABLED )
    return prefs
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
    onselect = [0, m, "AddAccount", "ClearHistory", "RedditSettings", "About"]

    uitkDoPosterMenu( settingmenu, screen, onselect )
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
    screen.AddParagraph("Version 1.6.1")
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

        plxml=CreateObject("roXMLElement")
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

Function createPref( prefName as String, prefDesc as String, prefDefault as Dynamic, prefValue as Dynamic, prefType as String, enumType = invalid as Dynamic ) as Object
    base = {}
    base.name = prefName
    base.value = prefValue
    base.default = prefDefault
    base.type = prefType
    base.desc = prefDesc
    base.values = getEnumValuesForType( prefType, enumType )
    return base
End Function

Function getEnumValuesForType( prefType as String, enumType = invalid as Dynamic) as Object
    retVal = invalid
    if ( prefType = "bool" ) then
        retVal = [ "false", "true" ]
    else if ( prefType = "enum" ) then
        if ( enumType = invalid ) then
            print "Enum type required for getEnumValuesForType with prefType of enum"
        else if ( enumType = Constants().eVID_QUALITY ) then
            retVal = [ "No Preference", "Force Highest", "Force Lowest" ]
        else if ( enumType = Constants().eENABLED_DISABLED ) then
            retVal = [ "Enabled", "Disabled" ]
        end if
    end if
    return retVal
End Function

Function Constants() as Object
    consts = {}
    consts.NO_PREFERENCE = 0
    consts.FORCE_HIGHEST = 1
    consts.FORCE_LOWEST = 2
    consts.FALSE_VALUE = 0
    consts.TRUE_VALUE = 1
    consts.ENABLED_VALUE = 0
    consts.DISABLED_VALUE = 1
    
    consts.eVID_QUALITY = "vidQuality"
    consts.eENABLED_DISABLED = "enabledDisabled"
    return consts
End Function