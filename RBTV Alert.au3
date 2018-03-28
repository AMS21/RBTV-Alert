
#comments-start
	MIT License

	Copyright (c) 2018 AMS21

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
#comments-end

#NoTrayIcon

#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Description=RBTV Alert
#AutoIt3Wrapper_Res_Fileversion=1.3.3
#AutoIt3Wrapper_Res_LegalCopyright=AMS21
#AutoIt3Wrapper_AU3Check_Stop_OnWarning=y
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/pe /sf /sv /rm /rsln
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <Array.au3>; For debug purpose
#include <Date.au3>
#include <FileConstants.au3>
#include <Misc.au3>
#include <StringConstants.au3>
#include <WinHTTP.au3>
#include <WinHTTPConstants.au3>

Global Const $sAppName = "RBTV Alert"

Global Const $sVersion = "1.3.3"
Global Const $sVersionState = " Release"

Global Const $sGitHubURL = "github.com"
Global Const $sGitHubLatestVersion = "AMS21/RBTV-Alert/releases/latest"
Global Const $sGitHubLink = "https://github.com/AMS21/RBTV-Alert"
Global Const $sGitHubIssuePage = $sGitHubLink & "/issues"
Global Const $sGitHubTagVersion = $sGitHubLink & "/releases/tag/"

Global Const $sUserAgentString = $sAppName & "/" & $sVersion & " (" & $sGitHubLink & ")"
Global Const $sServerURL = "www.rocketbeans.tv"
Global Const $sParamDetail = "details=1"
Global Const $sParamNextWeek = "nextWeek=1"
Global Const $sWochenPlanSubURL = "wochenplan/?" & $sParamDetail
Global Const $sWochenPlanSubURLNext = $sWochenPlanSubURL & "&" & $sParamNextWeek

Global Const $sRootFolder = @AppDataDir & "\" & $sAppName
Global Const $sIniPath = $sRootFolder & "\Config.ini"
Global Const $sDebugLogPath = $sRootFolder & "\Debug.log"
Global Const $sRequestLogPath = $sRootFolder & "\Request.htm"
Global Const $sInstallPath = @StartupDir & "\" & $sAppName & ".exe"

Global Const $asMonthAbr[] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

Global Enum $eWeekDay = 0, $eDate, $eName, $eGame, $eTime, $eDuration, $eInfo, $eMaxItems
#cs
	~	$eWeekDay = [Montag, Dienstag, Mittwoch, Donnerstag, Freitag, Samstag, Sonntag] (Day of the week)
	~	$eDate = DD. MMM YYYY (The month is a 3 letter abbreviation, see $asMonthAbr)
	~	$eName = name of the show, may not be empty
	~	$eGame = The game which is being played or some other additional info, can be empty
	~	$eTime = HH:DD (The time when the show will begin)
	~	$eDuration = H Std. MM Min. (The duration in hours and minutes)
	~			   = MM Min. (The duration only in minutes obviously less than 60)
	~	$eInfo = [None, Live, Premiere] (Whether the show is live, its the first time its shown (Premiere) or neither (None))
#ce

Global $iWeekNumber = -1

Global $cfg_asAlertNames
Global $cfg_bAlertLiveOnly
Global $cfg_bDebug
Global $cfg_iDateDiff
Global $cfg_bUseSSL
Global $cfg_bCheckForUpdate
Global $cfg_bAutoUpdate

Main()

Func Main()
	_DebugErase()
	_DebugWrite("RBTV Alert V." & $sVersion & $sVersionState & " started")

	; Installation / First time launch
	If _IsFirstLaunch() And @Compiled Then
		_DebugWrite("First time launch")

		_UpdateConfig()

		FileCopy(@ScriptFullPath, $sInstallPath, $FC_CREATEPATH)

		MsgBox($MB_OK, $sAppName, "Da du dieses Programm das erste Mal startest, hier ein paar Informationen." & @CRLF & "Das Programm wurde erfolgreich installiert und eine Standardkonfigurationdatei wurde erstellt." & @CRLF & @CRLF & "Autostart: " & $sInstallPath & @CRLF & "Konfigurationsdatei: " & $sIniPath & @CRLF & @CRLF & "Viel Spaß!")

		; Delayed self delete
		Run(@ComSpec & " /c " & 'del "' & @ScriptFullPath & '"', @ScriptDir, @SW_HIDE)
		Exit 0
	EndIf

	_LoadConfig()

	; Updating
	If $cfg_bCheckForUpdate Then
		_CheckForUpdate()
	EndIf

	_CheckInstalledVersion()

	; Getting the actual data
	Local $aShows = _GetWochenPlan()

	Local $sAlertString = ""

	For $i = 0 To UBound($aShows) - 1 Step 1
		For $j = 0 To UBound($cfg_asAlertNames) - 1 Step 1
			If (StringInStr($aShows[$i][$eName], $cfg_asAlertNames[$j]) Or StringInStr($aShows[$i][$eGame], $cfg_asAlertNames[$j])) And _IsDateInTheFuture($aShows[$i][$eDate], $aShows[$i][$eTime]) Then
				If ($cfg_bAlertLiveOnly And ($aShows[$i][$eInfo] = "Live" Or $aShows[$i][$eInfo] = "Premiere")) Or Not $cfg_bAlertLiveOnly Then
					$sAlertString &= @CRLF & @CRLF & $aShows[$i][$eName] & " " & $aShows[$i][$eGame] & @CRLF & $aShows[$i][$eWeekDay] & ": " & $aShows[$i][$eDate] & " " & $aShows[$i][$eTime] & " - " & _GetEndTime($aShows[$i][$eTime], $aShows[$i][$eDuration]) & @CRLF & "Duration: " & $aShows[$i][$eDuration]
					_DebugWrite("Event: iteration='" & $i & "' Name='" & $aShows[$i][$eName] & "' Game='" & $aShows[$i][$eGame] & "' WeekDay='" & $aShows[$i][$eWeekDay] & "' Date='" & $aShows[$i][$eDate] & "' Time='" & $aShows[$i][$eTime] & "' Duration='" & $aShows[$i][$eDuration] & "' Info='" & $aShows[$i][$eInfo] & "'")
				EndIf
			EndIf
		Next
	Next

	If $sAlertString <> "" Then
		MsgBox($MB_OK, $sAppName, "Upcoming Event!" & $sAlertString)
	Else
		_DebugWrite("No mentionable event found")
	EndIf

	Exit 0
EndFunc   ;==>Main

Func _GetWochenPlan()
	; Open WinHTTP with specific User Agent String
	Local $vOpen = _WinHttpOpen($sUserAgentString)
	If @error Then
		_DebugWrite("Error Opening WinHTTP Handle. @error=" & @error)
		_CreateCrashDump("Unable to open WinHTTP handle!")
	EndIf

	; Connect to Server
	Local $vConnect
	If $cfg_bUseSSL Then
		; If we use SSL Encryption connect to default HTTPS Port (443)
		$vConnect = _WinHttpConnect($vOpen, $sServerURL, $INTERNET_DEFAULT_HTTPS_PORT)
	Else
		; Else Connect to default HTTP Port (80)
		$vConnect = _WinHttpConnect($vOpen, $sServerURL, $INTERNET_DEFAULT_HTTP_PORT)
	EndIf
	If @error Then
		_DebugWrite("Error Opening WinHTTPConnect Handle. @error=" & @error)
		_CreateCrashDump("Unable to connect using WinHTTP")
	EndIf

	; Get the data from the Server
	Local $vRequest
	If $cfg_bUseSSL Then
		$vRequest = _WinHttpSimpleSSLRequest($vConnect, "GET", $sWochenPlanSubURL)
	Else
		$vRequest = _WinHttpSimpleRequest($vConnect, "GET", $sWochenPlanSubURL)
	EndIf
	If @error Then
		_DebugWrite("Unable to get this weeks plan. @error=" & @error)
		_CreateCrashDump($vRequest)
	EndIf

	; Get Next week data too
	Local $vRequestNextWeek
	If $cfg_bUseSSL Then
		$vRequestNextWeek = _WinHttpSimpleSSLRequest($vConnect, "GET", $sWochenPlanSubURLNext)
	Else
		$vRequestNextWeek = _WinHttpSimpleRequest($vConnect, "GET", $sWochenPlanSubURLNext)
	EndIf
	If @error Then
		_DebugWrite("Unable to get next weeks plan. @error=" & @error)
	EndIf

	; Debug
	If $cfg_bDebug Then
		Local $fHandle = FileOpen($sRequestLogPath, $FO_OVERWRITE + $FO_CREATEPATH)
		FileWrite($fHandle, $vRequest)
		FileClose($fHandle)
	EndIf

	; Get week numbers
	Local $aCurrentWeekNum = StringRegExp($vRequest, '(?i)(?s)<h2>Woche (\d+)</h2>', $STR_REGEXPARRAYGLOBALMATCH)

	If Not @error Then
		$iWeekNumber = $aCurrentWeekNum[0]
		_DebugWrite("current week number: " & $iWeekNumber)
	Else
		_DebugWrite("Error getting week number of current week")
		_CreateCrashDump($vRequest)
	EndIf

	Local $aNextWeekNum = StringRegExp($vRequestNextWeek, '(?i)(?s)<h2>Woche (\d+)</h2>', $STR_REGEXPARRAYGLOBALMATCH)

	If IsArray($aNextWeekNum) Then
		; if they have diffrent week numbers, ew. are for diffrent weeks, join them together and handle them both
		If $iWeekNumber < $aNextWeekNum[0] Then
			_DebugWrite("Got next week data for week number: " & $aNextWeekNum[0])
			$vRequest &= $vRequestNextWeek
		Else
			_DebugWrite("No next week data")
		EndIf
	Else
		_DebugWrite("No next week data")
	EndIf

	Local $aArrayResult[0][$eMaxItems]
	Local $iCount = 0
	Local $sCurrentDay, $sCurrentDate

	; Get all days
	Local $aArray = StringRegExp($vRequest, '(?i)(?s)<div class="day.*?">(.*?)\s+</div>\s+</div>\s+</div>', $STR_REGEXPARRAYGLOBALMATCH)

	If Not @error Then
		For $i = 0 To UBound($aArray) - 1 Step 1
			; Get Day Info like Date and Date name
			Local $aDayInfo = StringRegExp($aArray[$i], '(?i)(?s)<div class="dateHeader">.*?<h3>(.*?)</h3><span>(.*?)</span>.*?</div>', $STR_REGEXPARRAYGLOBALMATCH)
			If Not @error Then
				$sCurrentDay = $aDayInfo[0]
				$sCurrentDate = $aDayInfo[1]

				If $cfg_bDebug Then
					_DebugWrite("Day: '" & $sCurrentDay & "'")
					_DebugWrite("Date: '" & $sCurrentDate & "'")
				EndIf
			Else
				_DebugWrite("Failed to get date info at iteration: " & $i)
				_DebugWrite($aArray[$i])
				_CreateCrashDump($aArray[$i])
			EndIf

			Local $aShows = StringSplit($aArray[$i], '<div id="show-" class="show">', $STR_ENTIRESPLIT)
			If @error Then
				_DebugWrite("Unable to get shows at iteration: '" & $i & "' Day: '" & $sCurrentDay & "' Date: '" & $sCurrentDate & "'")
				_CreateCrashDump($aArray[$i])
			EndIf

			If $cfg_bDebug Then
				_DebugWrite("This day has " & $aShows[0] - 1 & " Shows")
			EndIf

			ReDim $aArrayResult[UBound($aArrayResult) + $aShows[0] - 1][$eMaxItems]

			; Iterate over every Show
			For $j = 2 To UBound($aShows) - 1 Step 1
				$aArrayResult[$iCount][$eDate] = $sCurrentDate
				$aArrayResult[$iCount][$eWeekDay] = $sCurrentDay

				Local $aTime = StringRegExp($aShows[$j], '(?i)<span class="scheduleTime">(.*?)</span>', $STR_REGEXPARRAYGLOBALMATCH)
				If @error Then
					_DebugWarning("Show has no shedule time!")
				Else
					_SanitizeString($aTime[0])
					$aArrayResult[$iCount][$eTime] = $aTime[0]
				EndIf

				; Show Name
				Local $aName = StringRegExp($aShows[$j], '(?i)<h4>(.*?)</h4>', $STR_REGEXPARRAYGLOBALMATCH)
				If @error Then
					_DebugWarning("Show at iteration '" & $iCount & "' has no name!")
					$aArrayResult[$iCount][$eName] = ""
				Else
					_SanitizeString($aName[0])
					$aArrayResult[$iCount][$eName] = $aName[0]
				EndIf

				; Game Name
				Local $aGameName = StringRegExp($aShows[$j], '(?i)<span class="game">(.*?)</span>', $STR_REGEXPARRAYGLOBALMATCH)
				If @error Then
					_DebugWrite("The show: '" & $aArrayResult[$iCount][$eName] & "' has no game!")
					$aArrayResult[$iCount][$eGame] = ""
				Else
					_SanitizeString($aGameName[0])
					$aArrayResult[$iCount][$eGame] = $aGameName[0]
				EndIf

				; Show Info and duration
				Local $aInfoDur = StringRegExp($aShows[$j], '(?i)(?s)<div class="showInfo">(.*?)<span class="showDuration">(.*?)</span>', $STR_REGEXPARRAYGLOBALMATCH)
				If @error Then
					_DebugWarning("Unable to get show info and duration from '" & $aArrayResult[$iCount][$eName] & "'!")
					$aArrayResult[$iCount][$eInfo] = "None"
					$aArrayResult[$iCount][$eDuration] = "00:00"
				Else
					_SanitizeString($aInfoDur[1])
					$aArrayResult[$iCount][$eInfo] = _GetShowStatus($aInfoDur[0])
					$aArrayResult[$iCount][$eDuration] = $aInfoDur[1]
				EndIf

				$iCount += 1
			Next
		Next
	Else
		_DebugWrite("Failed to get dates")
		_CreateCrashDump($vRequest)
	EndIf

	_DebugWrite("Total number of shows found: " & UBound($aArrayResult))

	Return $aArrayResult
EndFunc   ;==>_GetWochenPlan

Func _GetShowStatus(Const ByRef $sText)
	If StringInStr($sText, "live") Then
		Return "Live"
	ElseIf StringInStr($sText, "premiere") Then
		Return "Premiere"
	Else
		Return "None"
	EndIf
EndFunc   ;==>_GetShowStatus

Func _CheckForUpdate()
	_DebugWrite("Checking for updates")

	; Open WinHTTP with specific User Agent String
	Local $vOpen = _WinHttpOpen($sUserAgentString)
	If @error Then
		_DebugWrite("Error Opening WinHTTP Handle. @error=" & @error)
		_CreateCrashDump("Unable to open WinHTTP handle")
	EndIf

	; Connect to Server
	Local $vConnect
	If $cfg_bUseSSL Then
		; If we use SSL Encryption connect to default HTTPS Port (443)
		$vConnect = _WinHttpConnect($vOpen, $sGitHubURL, $INTERNET_DEFAULT_HTTPS_PORT)
	Else
		; Else Connect to default HTTP Port (80)
		$vConnect = _WinHttpConnect($vOpen, $sGitHubURL, $INTERNET_DEFAULT_HTTP_PORT)
	EndIf
	If @error Then
		_DebugWrite("Error Opening WinHTTPConnect Handle. @error=" & @error)
		_CreateCrashDump("Unable to connect using WinHTTP")
	EndIf

	; Get the data from the Server
	Local $vRequest
	If $cfg_bUseSSL Then
		$vRequest = _WinHttpSimpleSSLRequest($vConnect, "GET", $sGitHubLatestVersion)
	Else
		$vRequest = _WinHttpSimpleRequest($vConnect, "GET", $sGitHubLatestVersion)
	EndIf
	If @error Then
		_DebugWrite("Unable to get the following webpage: '" & $sGitHubURL & "/" & $sGitHubLatestVersion & "'. @error=" & @error)
		_CreateCrashDump($vRequest)
	EndIf

	Local $aLatestVersion = StringRegExp($vRequest, '(?i)<a href="/AMS21/RBTV-Alert/tree/(.+)" class="css-truncate">', $STR_REGEXPARRAYGLOBALMATCH)
	If @error Then
		_DebugWrite("Unable to extract latest version info")
		_CreateCrashDump($vRequest)
	EndIf
	_DebugWrite("This version: " & $sVersion & " most recent version: " & $aLatestVersion[0])

	Local $iComp = _VersionCompare($sVersion, $aLatestVersion[0])
	If $iComp == -1 Then
		_DebugWrite("Update available!")

		Local $aReleaseDate = StringRegExp($vRequest, '(?i)<relative-time datetime=".+?">(.+?)</relative-time>', $STR_REGEXPARRAYGLOBALMATCH)
		If @error Then
			_DebugWarning("No release date found!")
			_CreateCrashDump($vRequest)
		EndIf

		Local $aChangeLog = StringRegExp($vRequest, '(?i)(?s)<div class="markdown-body">.*?<ul>(.+?)</ul>.*?</div>', $STR_REGEXPARRAYGLOBALMATCH)
		If @error Then
			_DebugWarning("No changelog found!")
			_CreateCrashDump($vRequest)
		Else
			$aChangeLog = $aChangeLog[0]
			_CleanUpdateString($aChangeLog)
		EndIf

		If $cfg_bAutoUpdate Then
			_DebugWrite("Auto updating!")

			Local $aDownloadLink = StringRegExp($vRequest, '(?i)<a href="/(AMS21/RBTV-Alert/releases/download/.+/.+\.exe)" rel="nofollow">', $STR_REGEXPARRAYGLOBALMATCH)

			; Download the latest version
			Local $vDownload
			If $cfg_bUseSSL Then
				$vDownload = _WinHttpSimpleSSLRequest($vConnect, "GET", $aDownloadLink[0])
			Else
				$vDownload = _WinHttpSimpleRequest($vConnect, "GET", $aDownloadLink[0])
			EndIf
			If @error Then
				_DebugWrite("Unable to download the file. @error=" & @error)
				_CreateCrashDump($vDownload)
			EndIf

			Local $sPath = @TempDir & "\" & $sAppName & "-" & $aLatestVersion[0] & ".exe"

			Local $fHandle = FileOpen($sPath, $FO_OVERWRITE + $FO_CREATEPATH + $FO_BINARY)
			FileWrite($fHandle, $vDownload)
			FileClose($fHandle)

			_DebugWrite("Successfully downloaded new version to: '" & $sPath & "'")

			MsgBox($MB_OK, $sAppName, "Successfully updated " & $sAppName & " to version " & $aLatestVersion[0] & " released " & $aReleaseDate[0] & @CRLF & @CRLF & "Changelog: " & @CRLF & $aChangeLog)

			Run($sPath, @ScriptDir, @SW_SHOW)

			Exit 1
		Else
			Local $iResponse = MsgBox($MB_YESNO, $sAppName, "A new version (" & $aLatestVersion[0] & ") of " & $sAppName & " is available!" & @CRLF & @CRLF & "Release date: " & $aReleaseDate[0] & @CRLF & "Changelog:" & @CRLF & $aChangeLog & @CRLF & @CRLF & "Do you wish to proceed to the download page now?")

			If $iResponse == $IDYES Then
				_DebugWrite("Opened download page")
				ShellExecute($sGitHubTagVersion & $aLatestVersion[0])
			EndIf
		EndIf
	Else
		_DebugWrite("User already has the newest version")
	EndIf
EndFunc   ;==>_CheckForUpdate

Func _CleanUpdateString(ByRef $sString)
	$sString = StringReplace($sString, '<li>', '~ ')
	$sString = StringReplace($sString, '</li>', '')
	_SanitizeString($sString)
EndFunc   ;==>_CleanUpdateString

Func _CheckInstalledVersion()
	Local $sFileVersion = FileGetVersion($sInstallPath, $FV_FILEVERSION)

	_DebugWrite("This version: " & $sVersion & " Installed version: " & $sFileVersion)

	If _VersionCompare($sFileVersion, $sVersion) == -1 Then
		_DebugWrite("Updating installed version")

		FileCopy(@ScriptFullPath, $sInstallPath, $FC_OVERWRITE + $FC_CREATEPATH)

		_UpdateConfig()

		; Start the program
		Run($sInstallPath)

		; Delayed self delete
		Run(@ComSpec & " /c " & 'del "' & @ScriptFullPath & '"', @ScriptDir, @SW_HIDE)

		Exit 2
	Else
		_DebugWrite("Installed version is up to date")
	EndIf
EndFunc   ;==>_CheckInstalledVersion

Func _LoadConfig()
	$cfg_bAlertLiveOnly = __StringToBool(IniRead($sIniPath, "Config", "AlertLiveOnly", "True"))
	$cfg_asAlertNames = StringSplit(IniRead($sIniPath, "Config", "AlertNames", "Pen & Paper"), ",", $STR_ENTIRESPLIT + $STR_NOCOUNT)
	$cfg_bDebug = __StringToBool(IniRead($sIniPath, "Config", "Debug", Not @Compiled))
	$cfg_iDateDiff = Int(IniRead($sIniPath, "Config", "DateDiff", 3))
	$cfg_bUseSSL = __StringToBool(IniRead($sIniPath, "Config", "UseSSL", "False"))
	$cfg_bCheckForUpdate = __StringToBool(IniRead($sIniPath, "Config", "CheckForUpdate", "True"))
	$cfg_bAutoUpdate = __StringToBool(IniRead($sIniPath, "Config", "AutoUpdate", "True"))

	For $i = 0 To UBound($cfg_asAlertNames) - 1 Step 1
		_SanitizeString($cfg_asAlertNames[$i])
	Next

	_DebugWrite("Config successfully loaded!")
EndFunc   ;==>_LoadConfig

Func _UpdateConfig()
	_DebugWrite("Updating config")

	_CreateIniEntry("AlertLiveOnly", "True")
	_CreateIniEntry("AlertNames", "Pen & Paper")
	_CreateIniEntry("DateDiff", 3)
	_CreateIniEntry("UseSSL", "False")
	_CreateIniEntry("CheckForUpdate", "True")
	_CreateIniEntry("AutoUpdate", "True")
EndFunc   ;==>_UpdateConfig

Func _CreateIniEntry(Const ByRef $sKey, Const ByRef $sValue)
	If IniRead($sIniPath, "Config", $sKey, "") == "" Then
		IniWrite($sIniPath, "Config", $sKey, $sValue)
	EndIf
EndFunc   ;==>_CreateIniEntry

Func _CreateCrashDump(Const ByRef $sRequest)
	Local $sCrashDumpPath = $sRootFolder & "\CrashDump-" & @MDAY & @MON & @YEAR & "-" & @HOUR & @MIN & @SEC & ".dump"

	Local $fHandle = FileOpen($sCrashDumpPath, $FO_OVERWRITE + $FO_CREATEPATH)

	FileWriteLine($fHandle, $sAppName & " V." & $sVersion & $sVersionState & " Crashdump file created " & @MDAY & "." & @MON & "." & @YEAR & " " & @HOUR & ":" & @MIN & ":" & @SEC)

	FileWriteLine($fHandle, "") ; Blank line

	FileWriteLine($fHandle, "// Current config" & @CRLF)
	FileWriteLine($fHandle, "$cfg_asAlertNames.Size = " & UBound($cfg_asAlertNames))
	For $i = 0 To UBound($cfg_asAlertNames) - 1 Step 1
		FileWriteLine($fHandle, "$cfg_asAlertNames[" & $i & "] = '" & $cfg_asAlertNames[$i] & "'")
	Next
	FileWriteLine($fHandle, "$cfg_bAlertLiveOnly = " & String($cfg_bAlertLiveOnly))
	FileWriteLine($fHandle, "$cfg_bAutoUpdate = " & String($cfg_bAutoUpdate))
	FileWriteLine($fHandle, "$cfg_bCheckForUpdate = " & String($cfg_bCheckForUpdate))
	FileWriteLine($fHandle, "$cfg_bDebug = " & String($cfg_bDebug))
	FileWriteLine($fHandle, "$cfg_bUseSSL = " & String($cfg_bUseSSL))

	FileWriteLine($fHandle, "") ; Blank line

	Local $fHandleDLog = FileOpen($sDebugLogPath, $FO_READ)
	Local $sRead = FileRead($fHandleDLog)
	FileClose($fHandleDLog)

	FileWriteLine($fHandle, "// Debug Log")
	FileWrite($fHandle, $sRead)

	FileWriteLine($fHandle, "") ; Blank line

	FileWriteLine($fHandle, "// Input")
	FileWrite($fHandle, $sRequest)

	FileClose($fHandle)

	_DebugWrite("Successfully created crashdump file at '" & $sCrashDumpPath & "'")

	Local $iResponse = MsgBox($MB_YESNO, $sAppName, "Well thats embarrassing :/ An critical error occurred!" & @CRLF & "Please see the Crashdump file for further information." & @CRLF & @CRLF & "Crashdump: " & $sCrashDumpPath & @CRLF & @CRLF & "Click 'Yes' to open the issue page on GitHub. The program will exit now.")
	If $iResponse == $IDYES Then
		ShellExecute($sGitHubIssuePage)
	EndIf

	Exit -1
EndFunc   ;==>_CreateCrashDump

Func _GetEndTime(Const ByRef $sStartTime, Const ByRef $sDuration)
	; Extract start time
	Local $aStartTime = StringRegExp($sStartTime, '(?i)(\d+):(\d+)', $STR_REGEXPARRAYGLOBALMATCH)
	If @error Then
		_DebugWarning("Unable to retrive starting time information from: '" & $sStartTime & "', expected format: 'HH:MM'")
		_CreateCrashDump($sStartTime)
		Return -1
	EndIf

	Local $iHours = $aStartTime[0]
	Local $iMinutes = $aStartTime[1]

	Local $iHoursDuration = 0
	Local $iMinutesDuration = 0

	; Get hours of duration
	Local $aHours = StringRegExp($sDuration, '(?i)(\d+) Std\.', $STR_REGEXPARRAYGLOBALMATCH)
	If Not @error Then
		$iHoursDuration = $aHours[0]
	EndIf

	; Get minutes of duration
	Local $aMinutes = StringRegExp($sDuration, '(?i)(\d+) Min\.', $STR_REGEXPARRAYGLOBALMATCH)
	If Not @error Then
		$iMinutesDuration = $aMinutes[0]
	EndIf

	$iMinutes += $iMinutesDuration
	If $iMinutes >= 60 Then
		$iMinutes -= 60
		$iHours += 1
	EndIf

	$iHours += $iHoursDuration
	If $iHours >= 24 Then
		$iHours -= 24
	EndIf

	Return StringFormat("%02d:%02d", $iHours, $iMinutes)
EndFunc   ;==>_GetEndTime

Func _IsDateInTheFuture(Const ByRef $sDate, Const ByRef $sTime)
	Local $aComponents = StringRegExp($sDate, '(?i)(\d+)\.\s*(.*?)\s*(\d+)', $STR_REGEXPARRAYGLOBALMATCH)
	; 0 = Day
	; 1 = Month (3 letters abr.) see $asMonthAbr
	; 2 = Year

	If @error Then
		_DebugWrite("Error extracting date info, input: '" & $sDate & "', expected format 'DD. MMM YYYY'")
		_CreateCrashDump($sDate)
	EndIf

	For $i = 0 To UBound($asMonthAbr) - 1 Step 1
		If $aComponents[1] = $asMonthAbr[$i] Then
			$aComponents[1] = $i + 1 ; +1 because our array starts with 0, but our month with 1
			ExitLoop
		EndIf
	Next

	If Not IsInt($aComponents[1]) Then
		_DebugWrite("Error month name not found in the abbreviation list, $aComponents[1] = '" & $aComponents[1] & "'")
		_CreateCrashDump($aComponents[1])
	EndIf

	If $aComponents[0] >= @MDAY Or $aComponents[1] > @MON Or $aComponents[2] > @YEAR Then
		Local $iDateDiff = _DateDiff("h", _NowCalc(), $aComponents[2] & "/" & $aComponents[1] & "/" & $aComponents[0] & " " & $sTime)

		If $cfg_iDateDiff > 0 Then
			Return $iDateDiff >= 0 And $iDateDiff <= $cfg_iDateDiff * 24
		Else
			; ignore time diffrence
			Return $iDateDiff >= 0
		EndIf
	Else
		Return False
	EndIf
EndFunc   ;==>_IsDateInTheFuture

Func _SanitizeString(ByRef $sString)
	$sString = StringStripWS($sString, $STR_STRIPLEADING + $STR_STRIPTRAILING)
EndFunc   ;==>_SanitizeString

Func _IsFirstLaunch()
	Return Not (FileExists($sInstallPath) Or FileExists($sIniPath))
EndFunc   ;==>_IsFirstLaunch

Func __StringToBool(Const ByRef $sString)
	Return $sString = "True"
EndFunc   ;==>__StringToBool

Func _DebugWarning(Const ByRef $sDbgText)
	_DebugWrite("[Warning] " & $sDbgText)
EndFunc   ;==>_DebugWarning

Func _DebugWrite(Const ByRef $sDbgText)
	Local $fHandle = FileOpen($sDebugLogPath, $FO_APPEND + $FO_CREATEPATH)
	FileWrite($fHandle, "<" & @YEAR & "/" & @MON & "/" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & "." & @MSEC & "> " & $sDbgText & @CRLF)
	FileClose($fHandle)

	If Not @Compiled Or $cfg_bDebug Then
		ConsoleWrite($sDbgText & @CRLF)
	EndIf
EndFunc   ;==>_DebugWrite

Func _DebugErase()
	FileOpen($sDebugLogPath, $FO_OVERWRITE)
	FileClose($sDebugLogPath)
EndFunc   ;==>_DebugErase
