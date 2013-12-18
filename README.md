MyVideoBuzz -- Protuhj's Fork
=============

This project is fork of https://github.com/jesstech/Roku-YouTube, it is updated to fix the API changes and added new features and removed OAuth settings.


Installation
============

Enable development mode on your Roku Streaming Player with the following remote 
control sequence:

    Home 3x, Up 2x, Right, Left, Right, Left, Right

On newer versions of the Roku firmware, you will then be prompted to set the web server password. Choose a password (and remember it!), then reboot the Roku.

When development mode is enabled on your Roku, you can install dev packages
from the Application Installer which runs on your device at your device's IP
address. Open up a standard web browser and visit the following URL:

    http://<rokuPlayer-ip-address> (for example, http://192.168.1.6)

[Download the source as a zip](https://github.com/Protuhj/myvideobuzz/releases/download/v1.5/MyVideoBuzz_v1_5.zip) and upload it to your Roku device.

Due to limitations in the sandboxing of development Roku channels, you can only
have one development channel installed at a time.

### Alternative Installation Method - Windows users
============

Download the whole repository [Here - Current Release: 1.5](https://github.com/Protuhj/myvideobuzz/archive/v1.5.zip)
Edit the \deploy\rokus.txt file and add your Roku device(s) to the file, similar to this example:

    <Roku IP><space>rokudev:<rokupassword>
    192.168.1.56 rokudev:rokupassword

This will upload the myvideobuzz.zip file to the Rokus you provide in the rokus.txt file.

You can copy the .\deploy\ folder somewhere permanent on your hard drive, and modify the deploy.bat file to change the location of the zip file,
by changing the ZIP_LOCATION variable to point to the location of the zip you would like to deploy.

By doing this, you won't have to edit the rokus.txt in the future when updating your Rokus.

Advanced
========

### Debugging

Your Roku's debug console can be accessed by telnet at port 8085:

    telnet <rokuPlayer-ip-address> 8085

### Building from source

The [Roku Developer SDK](http://www.roku.com/developer) includes a handy Make script 
for automatically zipping and installing the channel onto your device should you make
any changes.  Just add the project to your SDK's `examples/source` folder and run the
`make install` command from that directory via your terminal.


Contributing
------------

Want to contribute? Great! Visit the subreddit here: http://www.reddit.com/r/VideoBuzz

Or Donate: <a href='https://pledgie.com/campaigns/23378'><img alt='Click here to lend your support to: VideoBuzz Development and make a donation at pledgie.com !' src='https://pledgie.com/campaigns/23378.png?skin_name=chrome' border='0' ></a>