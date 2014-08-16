MyVideoBuzz -- Protuhj's Fork
=============

This project is fork of https://github.com/jesstech/Roku-YouTube, it is updated to fix the API changes and added new features and removed OAuth settings.


Installation
============

Enable development mode on your Roku Streaming Player with the following remote 
control sequence:

**Note: This code cannot be entered from a mobile app (iOS, Android, etc.). You must use a physical Roku remote!**

    Home 3x, Up 2x, Right, Left, Right, Left, Right

On newer versions of the Roku firmware, you will then be prompted to set the web server password. Choose a password (and remember it!), then reboot the Roku.

When development mode is enabled on your Roku, you can install dev packages
from the Application Installer which runs on your device at your device's IP
address. Open up a standard web browser and visit the following URL:

    http://<rokuPlayer-ip-address> (for example, http://192.168.1.7)

[Download the source as a zip](https://github.com/Protuhj/myvideobuzz/releases/download/v1.7.3/MyVideoBuzz_v1_7_3.zip) and upload it to your Roku device.
**Do not unzip this file! Upload the whole file to your Roku!**

Due to limitations in the sandboxing of development Roku channels, you can only
have one development channel installed at a time.

<br/>

### Alternative Installation Method - Windows users

Download the whole repository [Here - Current Release: 1.7.3](https://github.com/Protuhj/myvideobuzz/archive/v1.7.3.zip)  
Unzip the file and edit the \deploy\rokus.txt file and add your Roku device(s) to the file, similar to this example:

    <Roku IP><space>rokudev:<rokupassword>
    192.168.1.56 rokudev:rokupassword

This will upload the myvideobuzz.zip file to the Rokus you provide in the rokus.txt file.

You can copy the .\deploy\ folder somewhere permanent on your hard drive, and modify the deploy.bat file to change the location of the zip file,
by changing the ZIP_LOCATION variable to point to the location of the zip you would like to deploy.

By doing this, you won't have to edit the rokus.txt in the future when updating your Rokus.

### Updating the channel

As of version 1.7.2, the channel supports auto-updating itself. That means, once the channel is installed, you can update it from within the channel itself.

* There are three ways the channel can update itself:
  1) A New Release (i.e. version is greater than the current version installed on your Roku, like 1.7.3 vs. 1.7.2).
  2) The current master (development) build has a newer version (major, minor, build #) than the currently installed version.
  3) Force the current latest release.

* **The only thing that needs to be done in order to use this feature, is to set your Roku password that you set when you enabled development mode.**
  * This can be used by going into the "Settings" item on the channel's main page, then the "General" item, then choose the "Roku Development Password" item, and enter your Roku's password. (The username is "rokudev" if that jars your memory.)
  * Once you've entered your password, go back to the main "Settings" page, and go to "About" -- you can then use the buttons at the bottom of the screen to choose which update option you'd like.

* Note: if a channel update is successful, there is no notification as such, it will just restart itself, like when you normally re-upload the channel's zip file.
<br/>
<br/>

### Usage

This channel uses publicly-available information from your YouTube account. In order to 
ensure that the channel works for you, you will need to make sure your Subscriptions, Playlists, and Favorites are publicly available.

* To do this, go to https://www.youtube.com/account_privacy and make sure the checkboxes under "Likes and Subscriptions" are unchecked.  
* Then, go to https://www.youtube.com/view_all_playlists to manage which playlists you would like to be visible in VideoBuzz.   
    * Click on the 'Edit' button next to each playlist you would like to change  
    * Then on the next page, click "Playlist settings" and change the "PLAYLIST PRIVACY" to Public.
<br/>
<br/>
<br/>

### Debugging

Your Roku's debug console can be accessed by telnet at port 8085:

    telnet <rokuPlayer-ip-address> 8085

<br/>
<br/>
<br/>
  
## Contributing


Want to contribute? Great! Visit the subreddit here: http://www.reddit.com/r/VideoBuzz  
You can also check out my Facebook page here: https://www.facebook.com/Protuhj

Or Donate: <a href='https://pledgie.com/campaigns/23378'><img alt='Click here to lend your support to: VideoBuzz Development and make a donation at pledgie.com !' src='https://pledgie.com/campaigns/23378.png?skin_name=chrome' border='0' ></a>
