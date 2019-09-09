# Installation

## Downloading

Download the soruce code from the git [repository](https://github.com/TheAngryDarling/dswift) to a location of your choosing and then extract the contents
Use git to download the repository 'git -c advice.detachedHead=false clone --branch latest https://github.com/TheAngryDarling/dswift.git' (WIthout the quotes)
You can change latest to a specific version if you like, but latest will download the most recent working version

## Compiling

Open up a termial and move to the root of the project folder. 
Run the command 'swift build -c release' (Without the quotes)
Make sure there are no errors in the output (Look for the word error)

## Installing

Run 'swift build -c release --show-bin-path' (without the quotes) to find the location of the buit executable and the path

For Linux: Run 'cp {location to executable} /usr/bin/'
For Mac: Run 'sudo cp {location to executable} /usr/local/bin/' You will be required to enter in your password to complete the copy process

## Test

Run the command 'dswift --version' (WIthout the quotes) and expect it to return 'Dynamic Swift version {some version}' as well as the current working version information for Swift

