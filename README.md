Google Android build tools for Ubuntu
=====================

Android build tools by Google packaged for Ubuntu

Visit the official website [here](http://mfonville.github.io/android-build-tools)

Based upon the work of @eighthave

## How-to
#### Install android-build-tools
Download pre-built packages from our [PPA](https://launchpad.net/~maarten-fonville/+archive/ubuntu/android-build-tools)

#### Build android-build-tools
Run configure with the parameters for the package you want to build:
```
./configure (xenial|bionic|disco|eoan)
```
E.g. if you want to make a package for bionic:
```
./configure bionic
```
After configuring you can build the package as usual with `debuild` or `pbuilder` in the *android-build-tools* folder

## FAQ
#### What does the installer do?
The installer contains a packaged script that automatically downloads Google's Android Build Tools package and unpacks it into Debian-friendly paths

#### Why doesn't main mainDexClasses work?
We still need to fix the proguard.sh dependency which is part of the *tools* package of the Android SDK
