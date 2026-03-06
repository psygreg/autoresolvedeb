# autoresolvedeb
Shell script to automate downloading DaVinci Resolve and running Daniel Tufvesson's *MakeResolveDeb* to convert it into a .deb package, then installing it. The second donation link is for Daniel, not myself, because of the usage of his work.

### Dependencies
This script depends on `whiptail`, `curl` and `wget`, besides `xorriso` and `fakeroot` required for building the .deb package.

## Usage
- Download `autoresolvedeb.sh`
- Right click and go to '*Properties*'
- Allow it to run as a program
- Right click and run as program

**On terminal**

`git clone https://github.com/psygreg/autoresolvedeb.git` \
`cd autoresolvedeb` \
`chmod +x autoresolvedeb.sh` \
`./autoresolvedeb.sh`

Just change permissions to allow execution and run it as a program.
License key or dongle for DaVinci Resolve Studio must be purchased in Blackmagic Design's official website. 
