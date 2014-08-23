
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

    if ( prefs.getPrefValue( consts.pTWITCH_ENABLED ) = consts.ENABLED_VALUE ) then
        menudata.Push({ShortDescriptionLine1:"Twitch", ShortDescriptionLine2: "Browse videos from Twitch.tv", Custom: true, ViewFunc: ViewTwitch, HDPosterUrl:"pkg:/images/twitch.jpg", SDPosterUrl:"pkg:/images/twitch.jpg"})
    end if

    if ( prefs.getPrefValue( consts.pREDDIT_ENABLED ) = consts.ENABLED_VALUE ) then
        menudata.Push({ShortDescriptionLine1:"Reddit", ShortDescriptionLine2: "Browse videos from reddit", Custom: true, ViewFunc: ViewReddits, HDPosterUrl:"pkg:/images/reddit.jpg", SDPosterUrl:"pkg:/images/reddit.jpg"})
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
    if ( prefs.getPrefValue( consts.pAUTO_UPDATE ) = consts.sUPDATE_REL ) then
        CheckForNewRelease( true )
    else if ( prefs.getPrefValue( consts.pAUTO_UPDATE ) = consts.sUPDATE_NEW ) then
        CheckForNewMaster( true )
    end if
    uitkDoPosterMenu(menudata, screen, onselect)
    sleep(25)
End Sub

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



