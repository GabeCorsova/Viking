#!/bin/zsh 
# shellcheck shell=bash
# shellcheck disable=SC2001
# this is to use sed in the case statements
# shellcheck disable=SC2034,SC2296
# these are due to the dynamic variable assignments used in the localization strings
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

: <<DOC
==============================================================================
Removing all Windows file from Application
==============================================================================
DOC
rm -rf /Applications/ConfigInfo.pdb /Applications/HalParser.pdb /Applications/InstallerUtils.dll.config /Applications/JobInfo.pdb /Applications/Mono.Zeroconf.Providers.Bonjour.dll.config /Applications/SimpleLog.dll.config /Applications/AdsInformation.dll /Applications/CaptionInfo.dll /Applications/CompCommunication.dll /Applications/ConfigInfo.dll /Applications/ConfigurationUtils.dll /Applications/DriverProfileInfo.dll /Applications/HalParser.dll /Applications/InstallerUtils.dll /Applications/JobInfo.dll /Applications/Mono.Zeroconf.Providers.Bonjour.dll /Applications/NetworkUtils.dll /Applications/Newtonsoft.Json.dll /Applications/NotifyPrint.dll /Applications/PipeCommunication.dll /Applications/PixDefault.dll /Applications/PrinterInfo.dll /Applications/SimpleLog.dll /Applications/SpoolerInformation.dll /Applications/stateController.dll /Applications/StatisticalManager.dll /Applications/UnixPrint.dll /Applications/UserInformation.dll /Applications/WSConfiguration_Info.dll /Applications/Printix\ Client.exe /Applications/Newtonsoft.Json.xml 