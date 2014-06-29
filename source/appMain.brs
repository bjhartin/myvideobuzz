
Sub Init()
    if (m.youtube = invalid) then
        m.youtube = InitYouTube()
    end if

    if ( m.constants = invalid ) then
        m.constants = LoadConstants()
    end if

    if ( m.prefs = invalid ) then
        m.prefs = LoadPreferences()
    end if
End Sub

Function getYoutube() As Object
    ' global singleton
    return m.youtube
End Function

Function getConstants() as Object
    return m.constants
End Function

Function getPrefs() as Object
    return m.prefs
End Function

Sub RunUserInterface()
    'initialize theme attributes like titles, logos and overhang color
    initTheme()
    ShowHomeScreen()
End Sub


Sub ShowHomeScreen()
    ' Pop up start of UI for some instant feedback while we load the icon data
    ytusername = RegRead("YTUSERNAME1", invalid)
    screen = uitkPreShowPosterMenu("flat-category", ytusername)
    if (screen = invalid) then
        'print "unexpected error in uitkPreShowPosterMenu"
        return
    end if

    Init()

    youtube = getYoutube()
    consts = getConstants()
    prefs = getPrefs()

    menudata=[]
     if (ytusername<>invalid) and (isnonemptystr(ytusername)) then
        menudata.Push({ShortDescriptionLine1:"What to Watch", FeedURL:"users/" + ytusername + "/newsubscriptionvideos?v=2&max-results=50&safeSearch=none", categoryData: invalid, ShortDescriptionLine2:"What's new to watch", HDPosterUrl:"pkg:/images/whattowatch.jpg", SDPosterUrl:"pkg:/images/whattowatch.jpg"})
        menudata.Push({ShortDescriptionLine1:"My Playlists", FeedURL:"users/" + ytusername + "/playlists?v=2&max-results=50&safeSearch=none", categoryData:{ isPlaylist: true }, ShortDescriptionLine2:"Browse your Playlists", HDPosterUrl:"pkg:/images/YourPlaylists.jpg", SDPosterUrl:"pkg:/images/YourPlaylists.jpg"})
        menudata.Push({ShortDescriptionLine1:"My Subscriptions", FeedURL:"users/" + ytusername + "/subscriptions?v=2&max-results=50", categoryData:{ isPlaylist: false }, ShortDescriptionLine2:"Browse your Subscriptions", HDPosterUrl:"pkg:/images/YourSubscriptions.jpg", SDPosterUrl:"pkg:/images/YourSubscriptions.jpg"})
        menudata.Push({ShortDescriptionLine1:"My Favorites", FeedURL:"users/" + ytusername + "/favorites?v=2&max-results=50&safeSearch=none", categoryData: invalid, ShortDescriptionLine2:"Browse your favorite videos", HDPosterUrl:"pkg:/images/YourFavorites.jpg", SDPosterUrl:"pkg:/images/YourFavorites.jpg"})
    end if
    menudata.Push({ShortDescriptionLine1:"History", OnClick:"ShowHistory", ShortDescriptionLine2:"View your history",  HDPosterUrl:"pkg:/images/History.png", SDPosterUrl:"pkg:/images/History.png"})
    menudata.Push({ShortDescriptionLine1:"Search", OnClick:"SearchYoutube", ShortDescriptionLine2:"Search YouTube for videos",  HDPosterUrl:"pkg:/images/Search.jpg", SDPosterUrl:"pkg:/images/Search.jpg"})
    menudata.Push({ShortDescriptionLine1:"Local Network", Custom: true, ViewFunc: CheckForLANVideos, categoryData:invalid, ShortDescriptionLine2:"View recent LAN videos", HDPosterUrl:"pkg:/images/LAN.jpg", SDPosterUrl:"pkg:/images/LAN.jpg"})
    if ( prefs.getPrefValue( consts.pREDDIT_ENABLED ) = consts.ENABLED_VALUE ) then
        menudata.Push({ShortDescriptionLine1:"Reddit", ShortDescriptionLine2: "Browse videos from reddit", Custom: true, ViewFunc: ViewReddits, HDPosterUrl:"pkg:/images/reddit_beta.jpg", SDPosterUrl:"pkg:/images/reddit_beta.jpg"})
    end if
    menudata.Push({ShortDescriptionLine1:"Top Channels", FeedURL:"pkg:/xml/topchannels.xml", categoryData:{ isPlaylist: false },  ShortDescriptionLine2:"Top Channels", HDPosterUrl:"pkg:/images/TopChannels.jpg", SDPosterUrl:"pkg:/images/TopChannels.jpg"})
    menudata.Push({ShortDescriptionLine1:"Most Popular", FeedURL:"pkg:/xml/mostpopular.xml", categoryData:{ isPlaylist: false },  ShortDescriptionLine2:"Most Popular Videos", HDPosterUrl:"pkg:/images/MostPopular.jpg", SDPosterUrl:"pkg:/images/mostpopular.jpg"})
    menudata.Push({ShortDescriptionLine1:"Settings", OnClick:"BrowseSettings", ShortDescriptionLine2:"Edit channel settings", HDPosterUrl:"pkg:/images/Settings.jpg", SDPosterUrl:"pkg:/images/Settings.jpg"})

    onselect = [1, menudata, m.youtube,
        function(menu, youtube, set_idx)
            if (menu[set_idx]["FeedURL"] <> invalid) then
                feedurl = menu[set_idx]["FeedURL"]
                youtube.FetchVideoList(feedurl,menu[set_idx]["ShortDescriptionLine1"], invalid, menu[set_idx]["categoryData"])
            else if (menu[set_idx]["OnClick"] <> invalid) then
                onclickevent = menu[set_idx]["OnClick"]
                youtube[onclickevent]()
            else if (menu[set_idx]["Custom"] = true) then
                    menu[set_idx]["ViewFunc"](youtube)
            end if
            return set_idx
        end function]
    MulticastInit(youtube)
    'uitkDoPosterMenu(menudata, screen, onselect)
    update()
    sleep(2500)
    print "Done"
End Sub

Sub update()
    
    port = CreateObject( "roMessagePort" )
    log = CreateObject( "roSystemLog" )
    log.SetMessagePort( port )
    log.EnableType( "http.error" )
    log.EnableType( "http.connect" )
    ut = CreateObject("roUrlTransfer")
    ut.SetPort( port )
    'ut.SetUserAndPassword( "rokudev", "roku" )
    ut.SetCertificatesFile( "common:/certs/ca-bundle.crt" )
    ut.SetCertificatesDepth( 3 )
    ut.InitClientCertificates()
    ut.SetUrl( "https://github.com/Protuhj/myvideobuzz/releases/download/v1.7/MyVideoBuzz_v1_7.zip" )
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
                print "Response received: " + msg.GetString()
                
                status = msg.GetResponseCode()
                print "received Status: " ; tostr( status )
                if ( respCount > 2 ) then
                    exit while
                end if
                if ( status = 200 ) then
                    if ( fs.Exists( "tmp:/temp.zip" ) = true ) then
                        print "File exists, size: " ; tostr( fs.Stat( "tmp:/temp.zip"  ).size )
                        ut2.SetUserAndPassword( "rokudev", "roku" )
                        ut2.SetUrl( "http://192.168.1.5/plugin_install" )
                       ' ut2.SetUrl( "http://192.168.1.231:80/plugin_install" )
                       ' ut.AsyncGetToString()
                        ct = "multipart/form-data; boundary=" + boundary$ + " " + boundary$
                        print "CT: " ; ct
                        ut2.AddHeader("Content-Type", ct )
                        ut2.AddHeader("Content-Disposition", GetContentDisposition2( "Install", boundary$ ) )
                        ut2.AddHeader("Content-Disposition", GetContentDisposition( "temp.zip" ) )
                        ut2.AddHeader("Content-Type", "application/octet-stream")
                        ret = ut2.AsyncPostFromFile( "tmp:/temp.zip" )
                        'ret = ut2.AsyncPostFromString( "" )
                        print "Result: " ; tostr( ret )
                    end if
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
        print "Delete succeeded: " ; tostr( fs.Delete( "tmp:/temp.zip" ) )
    else
        print "File doesn't exist"
    end if
    
End Sub

Function GetContentDisposition(file As String) As String

'Content-Disposition: form-data; name="file"; filename="UploadPlaylog.xml"

    contentDisposition$ = "form-data; name="
    contentDisposition$ = contentDisposition$ + chr(34)
    contentDisposition$ = contentDisposition$ + "archive"
    contentDisposition$ = contentDisposition$ + chr(34)
    contentDisposition$ = contentDisposition$ + "; filename="
    contentDisposition$ = contentDisposition$ + chr(34)
    contentDisposition$ = contentDisposition$ + file
    contentDisposition$ = contentDisposition$ + chr(34)

    return contentDisposition$
    
End Function

Function GetContentDisposition2(file As String, boundary as String) As String

'Content-Disposition: form-data; name="file"; filename="UploadPlaylog.xml"

    contentDisposition$ = "form-data; name=" + chr(34) + "mysubmit" + chr(34) + " " + file + " " + boundary

    return contentDisposition$
    
End Function

'*************************************************************
'** Set the configurable theme attributes for the application
'**
'** Configure the custom overhang and Logo attributes
'*************************************************************

Sub initTheme()
    app = CreateObject("roAppManager")
    theme = CreateObject("roAssociativeArray")
    theme.OverhangOffsetSD_X = "72"
    theme.OverhangOffsetSD_Y = "31"
    theme.OverhangSliceSD = "pkg:/images/Overhang_Background_SD.png"
    theme.OverhangLogoSD  = "pkg:/images/Overhang_Logo_SD.png"

    theme.OverhangOffsetHD_X = "125"
    theme.OverhangOffsetHD_Y = "25"
    theme.OverhangSliceHD = "pkg:/images/Overhang_Background_HD.png"
    theme.OverhangLogoHD  = "pkg:/images/Overhang_Logo_HD.png"
    theme.BackgroundColor = "#232B30"

    textColor = "#B7DFF8"
    theme.ListScreenTitleColor      = "#92b2c6"
    theme.ListScreenDescriptionText = "#92b2c6"
    theme.ListScreenHeaderText      = "#92b2c6"
    theme.GridScreenListNameColor   = "#FFFFFF"
    theme.GridScreenMessageColor   = "#FFFFFF"
    theme.GridScreenRetrievingColor   = "#FFFFFF"
    theme.TextScreenBodyBackgroundColor   = "#FFFFFF"
    theme.ListItemText              = textColor
    theme.ListItemHighlightText     = textColor
    theme.PosterScreenLine1Text     = textColor
    theme.PosterScreenLine2Text     = textColor
    theme.EpisodeSynopsisText       = textColor
    theme.ParagraphBodyText         = textColor
    theme.ParagraphHeaderText       = textColor
    theme.SpringboardTitleText      = textColor
    theme.SpringboardRuntimeColor   = textColor
    theme.SpringboardGenreColor     = textColor
    theme.SpringboardSynopsisColor  = textColor
    theme.SpringboardAllow6Buttons  = "true"

    theme.FilterBannerActiveColor   = textColor
    theme.ButtonMenuNormalText   = textColor
    theme.ButtonHighlightColor   = textColor

    app.SetTheme(theme)
End Sub



