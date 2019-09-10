# Installation

## Simplified

### Downloading

Download the updater script from the git [repository](https://raw.githubusercontent.com/TheAngryDarling/dswift/master/dswift-update) 
Move the script to your bin directory:

For Linux: Run 'curl -o /usr/bin/dswift-update https://raw.githubusercontent.com/TheAngryDarling/dswift/master/dswift-update'
For Mac: Run 'sudo curl -o /usr/local/bin/dswift-update https://raw.githubusercontent.com/TheAngryDarling/dswift/master/dswift-update' You will be required to enter in your password to complete the copy process

### Grant Permissions

For Linux: Run 'chmod +x /usr/bin/dswift-update'
For Mac: Run 'sudo chmod +x /usr/local/bin/dswift-update' You maybe required to enter in your password to complete the permission process

### Installation

Run the update script to download/compile/install dswift on your system
For Linux: Run 'dswift-update'
for Mac: Run 'sudo dswift-update' You maybe required to enter in your password to complete the installation process

## Manually

### Downloading

Download the soruce code from the git [repository](https://github.com/TheAngryDarling/dswift) to a location of your choosing and then extract the contents
Use git to download the repository 'git -c advice.detachedHead=false clone --branch latest https://github.com/TheAngryDarling/dswift.git' (WIthout the quotes)
You can change latest to a specific version if you like, but latest will download the most recent working version

### Compiling

Open up a termial and move to the root of the project folder. 
Run the command 'swift build -c release' (Without the quotes)
Make sure there are no errors in the output (Look for the word error)

### Installing

Run 'swift build -c release --show-bin-path' (without the quotes) to find the location of the buit executable and the path

For Linux: Run 'cp {location to executable} /usr/bin/'
For Mac: Run 'sudo cp {location to executable} /usr/local/bin/' You will be required to enter in your password to complete the copy process

## Test

Run the command 'dswift --version' (WIthout the quotes) and expect it to return 'Dynamic Swift version {some version}' as well as the current working version information for Swift

