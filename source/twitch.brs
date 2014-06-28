'******************************************************************************
' reddit.brs
' Adds support for handling reddit's json feed for subreddits
' Documentation on the API is here:
'             http://www.reddit.com/dev/api#section_listings
'******************************************************************************

'******************************************************************************
' Main function to begin displaying subreddit content
' @param youtube the current youtube instance
' @param url an optional URL with the multireddit to query, or the full link to parse. This is used when hitting the 'More Results' or 'Back' buttons on the video list page.
'     multireddits look like this: videos+funny+humor for /r/videos, /r/funny, and /r/humor
'******************************************************************************
Sub ViewTwitch(youtube as Object)
    'https://api.twitch.tv/kraken/games/top?hls=true
    title = "Twitch Games"
    screen = uitkPreShowPosterMenu( "arced-portrait", title )
    screen.showMessage( "Loading Twitch games..." )
    rsp = QueryForJson( "https://api.twitch.tv/kraken/games/top?hls=true" )
    'printAA( rsp )
    if ( rsp.status = 200 ) then
        gameList = newTwitchGameList( rsp.json )
        ' Now add the 'More results' button
        for each link in rsp.json._links
            if (type(link) = "roAssociativeArray") then
                if (link.type = "next") then
                    gameList.Push({shortDescriptionLine1: "More Results", action: "next", HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg"})
                end if
            end if
        end for
        ' gameList.Unshift({shortDescriptionLine1: "Back", action: "prev", HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg"})
        onselect = [1, gameList, m.youtube,
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
        uitkDoPosterMenu(gameList, screen, onselect)
    end if
End Sub

Function NewTwitchGameList(jsonObject As Object) As Object
    gameList = []
    constants = getConstants()
    for each record in jsonObject.top
        gameList.Push( NewTwitchGameLink( record ) )
    next
    return gameList
End Function

'******************************************************************************
' Creates a video roAssociativeArray, with the appropriate members needed to set Content Metadata and play a video with
' This function handles sites that require parsing a response for an MP4 URL (LiveLeak, Vine)
' @param jsonObject the JSON "data" object that was received in QueryForJson, this is one result of many
' @return an roAssociativeArray of metadata for the current result
'******************************************************************************
Function NewTwitchGameLink(jsonObject As Object) As Object
    game                   = {}

    game["ID"]                      = tostr( jsonObject.game._id )
    game["TitleSeason"]             = jsonObject.game.name
    game["Categories"]              = "Vidya Game"
    game["Description"]             = ""
    game["Source"]                  = "Twitch"
    game["Thumb"]                   = jsonObject.game.box.large
    game["ContentType"]             = "game"
    game["Title"]                   = "Viewers: " + tostr( jsonObject.viewers )
    game["FullDescription"]         = ""
    game["Description"]             = tostr( jsonObject.channels ) + " Channels"
    game["ShortDescriptionLine1"]   = game["TitleSeason"]
    game["ShortDescriptionLine2"]   = game["Title"]
    game["SDPosterUrl"]             = jsonObject.game.box.medium
    game["HDPosterUrl"]             = jsonObject.game.box.large
    return game
End Function
