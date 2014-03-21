'********************************************************************
' Initializes the UDP objects for use in the application.
' @param youtube the current youtube object
'********************************************************************
Sub MulticastInit(youtube as Object)
    msgPort = createobject("roMessagePort")
    udp = createobject("roDatagramSocket")
    udp.setMessagePort(msgPort)
    addr = createobject("roSocketAddress")
    addr.setPort(6789)
    addr.SetHostName("224.0.0.115")
    udp.setAddress(addr)
    if (not(udp.setSendToAddress(addr))) then
        print ("Failed to set send to address")
        return
    end if
    ' Only local subnet
    udp.SetMulticastTTL(1)
    if (not(udp.SetMulticastLoop(false))) then
        print("Failed to disable multicast loop")
    end if
    ' Join the multicast group
    udp.joinGroup(addr)
    udp.NotifyReadable(true)
    udp.NotifyWritable(false)
    youtube.dateObj.Mark()
    youtube.udp_created = youtube.dateObj.AsSeconds()
    youtube.udp_socket = udp
    youtube.mp_socket = msgPort

    dialMsgPort = createobject("roMessagePort")
    DIAL_udp = createobject("roDatagramSocket")
    DIAL_udp.setMessagePort(dialMsgPort)
    DIAL_addr = createobject("roSocketAddress")
    DIAL_addr.setPort(1900)
    DIAL_addr.SetHostName("239.255.255.250")
    DIAL_udp.setAddress(DIAL_addr)
    if (not(DIAL_udp.setSendToAddress(DIAL_addr))) then
        print ("Failed to set send to address for DIAL UDP socket")
        return
    end if
    ' Only local subnet
    DIAL_udp.SetMulticastTTL(1)
    if (not(DIAL_udp.SetMulticastLoop(false))) then
        print("Failed to disable multicast loop")
    end if
    ' Join the multicast group
    DIAL_udp.joinGroup(DIAL_addr)
    DIAL_udp.NotifyReadable(true)
    DIAL_udp.NotifyWritable(false)
    youtube.DIAL_socket = DIAL_udp
    youtube.mp_DIAL = dialMsgPort
End Sub

'********************************************************************
' Makes sure the UDP socket and message port stay fresh.
' FIxes an issue where the message port seemingly becomes 'stale'
' after a few hours of inactivity
' Currently, the period is one hour, which seems like a decent number
' @param youtube the current youtube object
'********************************************************************
Sub HandleStaleMessagePort( youtube as Dynamic )
    youtube.dateObj.Mark()
    ' Re-initialize the socket and message port every hour to avoid a stale message port
    if ( ( youtube.dateObj.AsSeconds() - youtube.udp_created ) > 3600 ) then
        youtube.udp_socket.Close()
        youtube.mp_socket = invalid
        youtube.DIAL_socket.Close()
        youtube.mp_DIAL = invalid
        MulticastInit( youtube )
    end if
End Sub

'********************************************************************
' Determines if someone on the network has tried to query for other videos on the LAN
' Listens for active video queries, and responds if necessary
'********************************************************************
Sub CheckForMCast()
    youtube = LoadYouTube()
    if (youtube.mp_socket = invalid OR youtube.udp_socket = invalid) then
        print("CheckForMCast: Invalid Message Port or UDP Socket")
        return
    end if

    message = youtube.mp_socket.GetMessage()
    ' Flag to track if a response is necessary -- we only want to respond once,
    ' even if we find multiple queries available on the socket
    mvbRespond = false
    while (message <> invalid)
        if (type(message) = "roSocketEvent") then
            data = youtube.udp_socket.receiveStr(4096) ' max 4096 characters

            ' Replace newlines
            data = youtube.regexNewline.ReplaceAll( data, "" )
            ' print("Received " + Left(data, 2) + " from " + Mid(data, 3))
            if ((Left(data, 2) = "1?") AND (Mid(data, 3) <> youtube.device_id)) then
                ' Nothing to do if there's no video to watch
                if (youtube.history <> invalid AND youtube.history.Count() > 0) then
                    mvbRespond = true
                end if
            else if ((Left(data, 2) = "2:")) then ' Allow push of videos from other sources on the LAN (not implemented within this source)
                print("Received force: " + Mid(data, 3))
                'youtube.activeVideo = ParseJson(Mid(data, 3))
            else if ((Left(data, 2) = "1:")) then
                ' print("Received udp response: " + Mid(data, 3))
            end if
        end if
        ' This effectively drains the receive queue
        message = wait(10, youtube.mp_socket)
    end while
    if (mvbRespond = true) then
        json = SimpleJSONBuilder(youtube.history[0])
        if (json <> invalid) then
            ' Replace all newlines in the JSON
            json = youtube.regexNewline.ReplaceAll(json, "")
            youtube.udp_socket.SendStr("1:" +  json)
        end if
    end if
    
    CheckForDIALMCast()

    ' Determine if the udp socket and message port need to be re-initialized
    HandleStaleMessagePort( youtube )
End Sub

Sub CheckForDIALMCast()
    youtube = LoadYouTube()
    if (youtube.mp_DIAL = invalid OR youtube.DIAL_socket = invalid) then
        print("CheckForDIALMCast: Invalid Message Port or UDP Socket")
        return
    end if

    message = youtube.mp_DIAL.GetMessage()
    ' Flag to track if a response is necessary -- we only want to respond once,
    ' even if we find multiple queries available on the socket
    mvbRespond = false
    sendToAddress = invalid
    while (message <> invalid)
        if (type(message) = "roSocketEvent") then
            data = youtube.DIAL_socket.receiveStr(4096) ' max 4096 characters

            ' Replace newlines
            print("Received " + data)
            if ( data.instr( 0, "M-SEARCH" ) AND ( data.instr( 0, "urn:dial-multiscreen-org:service:dial:1" ) ) ) then


                if ( NOT( youtube.dial_server_active ) ) then
                    'DatagramPacket newData = new DatagramPacket( resp.getBytes(), resp.length(), data.getAddress(), data.getPort())
                    sendToAddress = youtube.DIAL_socket.GetReceivedFromAddress()
                    's.send(newData)
                    mvbRespond = true
                end if
            end if
        end if
        ' This effectively drains the receive queue
        message = wait( 10, youtube.mp_DIAL )
    end while
    if ( mvbRespond = true AND sendToAddress <> invalid ) then
        resp = getResponseString()
        print("Responding with: " + resp)
        youtube.DIAL_socket.setSendToAddress( sendToAddress )
        youtube.DIAL_socket.SendStr("1:" +  resp)
    end if
    ' Determine if the udp socket and message port need to be re-initialized
    HandleStaleMessagePort( youtube )
End Sub
'********************************************************************
' Determines if there are available videos on the LAN to continue watching
' Multicasts a query for other listening devices to respond with their currently-active video
' This function is a callback handler for the main menu
' @param youtube the current youtube object
'********************************************************************
Sub CheckForLANVideos(youtube as Object)
    jsonMetadata = []
    if (youtube.mp_socket = invalid OR youtube.udp_socket = invalid) then
        print("CheckForMCast: Invalid Message Port or UDP Socket")
        return
    end if
    dialog = ShowPleaseWait("Searching for videos on your LAN")
    ' Multicast query
    youtube.udp_socket.SendStr("1?" + youtube.device_id)
    ' Wait a maximum of 5 seconds for a response
    t = CreateObject("roTimespan")
    message = wait(2500, youtube.mp_socket)
    while (message <> invalid OR t.TotalSeconds() < 5)
        if (type(message) = "roSocketEvent") then
            data = youtube.udp_socket.receiveStr(4096) ' max 4096 characters
            ' print("Received " + Left(data, 2) + " from " + Mid(data, 3))
            ' Replace newlines -- this WILL screw up JSON parsing
            data = youtube.regexNewline.ReplaceAll( data, "" )
            if ((Left(data, 2) = "1:")) then
                response = Mid(data, 3)
                ' print("Received udp response: " + response)
                jsonObj = ParseJson(response)
                if (jsonObj <> invalid) then
                    foundInList = false
                    for each vid in jsonMetadata
                        if ( vid["ID"] = jsonObj["ID"] ) then
                            foundInList = true
                            exit for
                        end if
                    end for
                    if (not(foundInList)) then
                        jsonMetadata.Push(jsonObj)
                    end if
                end if
            end if
        ' else the message is invalid
        end if
        ' If we continue to receive valid roSocketEvent messages, we still want to limit the query to 5 seconds
        if (t.TotalSeconds() > 5 OR jsonMetadata.Count() > 50) then
            exit while
        end if
        message = wait(100, youtube.mp_socket)
    end while
    print("Found " + tostr(jsonMetadata.Count()) + " LAN Videos")
    dialog.Close()
    youtube.DisplayVideoListFromMetadataList(jsonMetadata, "LAN Videos", invalid, invalid, invalid)
End Sub

Function GetDIALPort() as String
    return "23456"
End Function

Function getDeviceString() as String
    return ("<?xml version=" + Quote() + "1.0" + Quote() + "?><root xmlns=" + Quote() +"urn:schemas-upnp-org:device-1-0" + Quote() + "><specVersion><major>1</major><minor>0</minor></specVersion><URLBase>http://" + GetRokuLocalIP() + ":" + GetDIALPort() + "</URLBase><device><deviceType>urn:dial-multiscreen-org:device:dial:1</deviceType><friendlyName>VideoBuzz</friendlyName><manufacturer>Protuhj</manufacturer><modelName>Roku</modelName><UDN>uuid:abd55251-466f-473b-893d-34507dba84ef</UDN><iconList><icon><mimetype>image/png</mimetype><width>98</width><height>55</height><depth>32</depth><url>/setup/icon.png</url></icon></iconList><serviceList><service><serviceType>urn:dial-multiscreen-org:service:dial:1</serviceType><serviceId>urn:dial-multiscreen-org:serviceId:dial</serviceId><controlURL>/ssdp/notfound</controlURL><eventSubURL>/ssdp/notfound</eventSubURL><SCPDURL>/ssdp/notfound</SCPDURL></service></serviceList></device></root>")
End Function

Function getResponseString() as String

    return ( "HTTP/1.1 200 OK\nLOCATION: http://" + GetRokuLocalIP() + ":" + GetDIALPort() + "/dd.xml\nCACHE-CONTROL: max-age=1800\nEXT:\nCONFIGID.UPNP.ORG: 8008\nBOOTID.UPNP.ORG: 8008\nST: urn:dial-multiscreen-org:service:dial:1\nUSN: uuid:abd55251-466f-473b-893d-34507dba84ef\n\n" )
End Function

Function GetRokuLocalIP() As String
    deviceInfo = CreateObject("roDeviceInfo")
    ipAddresses = deviceInfo .GetIPAddrs()
    For Each key In ipAddresses
        ipAddress = ipAddresses[key]
        If ipAddress <> invalid And ipAddress.Len() > 0 Then
            Return ipAddress
        End If
    Next
    Return ""
End Function
