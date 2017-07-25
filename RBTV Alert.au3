
#comments-start
	MIT License

	Copyright (c) 2017 CppAndre

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
#RequireAdmin

#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Description=RBTV Alert script
#AutoIt3Wrapper_Res_Fileversion=1.0
#AutoIt3Wrapper_Res_LegalCopyright=AMS
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#AutoIt3Wrapper_AU3Check_Parameters=-w 1 -w 2 -w 3 -w 4 -w 5 -w 6
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/pe /sf /sv /rm /rsln
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <Array.au3>; For debug purpose
#include <Date.au3>
#include <FileConstants.au3>
#include <StringConstants.au3>
#include <WinHTTP.au3>
#include <WinHTTPConstants.au3>

Global Const $sAppName = "RBTV Alert"

Global Const $sVersion = "1.0"
Global Const $sVersionState = " Release"

Global Const $sGitHubLink = "https://github.com/CppAndre/RBTV-Alert"

Global Const $sUserAgentString = $sAppName & "/" & $sVersion & " (" & $sGitHubLink & ")"
Global Const $sServerURL = "www.rocketbeans.tv"
Global Const $sParamDetail = "details=1"
Global Const $sParamNextWeek = "nextWeek=1"
Global Const $sWochenPlanSubURL = "wochenplan/?" & $sParamDetail
Global Const $sWochenPlanSubURLNext = $sWochenPlanSubURL & "&" & $sParamNextWeek

Global Const $sRootFolder = @AppDataDir & "\" & $sAppName
Global Const $sIniPath = $sRootFolder & "\Config.ini"
Global Const $sDebugLogPath = $sRootFolder & "\Debug.log"
Global Const $sInstallPath = @StartupDir & "\" & $sAppName & ".exe"

Global Const $asMonthAbr[] = ["Jan", "Feb", "M‰r", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]

Global Enum $eWeekDay = 0, $eDate, $eName, $eGame, $eTime, $eTimeSpan, $eInfo, $eMaxItems

Global $iWeekNumber = -1

Global $cfg_asAlertNames
Global $cfg_bAlertLiveOnly
Global $cfg_bDebug
Global $cfg_iDateDiff
Global $cfg_bUseSSL

_DebugErase()

_DebugWrite($sAppName & " V." & $sVersion & $sVersionState & " started")

If _IsFirstLaunch() And @Compiled Then
	_DebugWrite("First time launch")

	_CreateDefaultConfig()

	FileCopy(@ScriptFullPath, $sInstallPath, $FC_CREATEPATH)

	$response = MsgBox($MB_OK, $sAppName, "Da du dieses Programm das erste Mal startest, hier ein paar Informationen." & @CRLF & "Das Programm wurde erfolgreich installiert und eine Standardkonfigurationdatei wurde erstellt." & @CRLF & @CRLF & "Autostart: " & $sInstallPath & @CRLF & "Konfigurationsdatei: " & $sIniPath & @CRLF & @CRLF & "Viel Spaﬂ!")

	; Delayed self delete
	Run(@ComSpec & " /c " & 'del "' & @ScriptFullPath & '"', @ScriptDir, @SW_HIDE)
	Exit 0
EndIf

_LoadConfig()

$aShows = _GetWochenPlan()
If $aShows = -1 Then
	_DebugWrite("Invalid data from _GetWochenPlan()")
	Exit -1
EndIf

$sAlertString = ""

For $i = 0 To UBound($aShows) - 1 Step 1
	For $j = 0 To UBound($cfg_asAlertNames) - 1 Step 1
		If StringInStr($aShows[$i][$eName], $cfg_asAlertNames[$j]) And _IsDateInTheFuture($aShows[$i][$eDate]) Then
			If ($cfg_bAlertLiveOnly And ($aShows[$i][$eInfo] = "Live" Or $aShows[$eInfo] = "Premiere")) Or Not $cfg_bAlertLiveOnly Then
				$sAlertString &= @CRLF & @CRLF & $aShows[$i][$eName] & " " & $aShows[$i][$eGame] & @CRLF & $aShows[$i][$eWeekDay] & ": " & $aShows[$i][$eDate] & " " & $aShows[$i][$eTime] & @CRLF & "Duration: " & $aShows[$i][$eTimeSpan]
				_DebugWrite("Event: iteration=" & $i & " Name=" & $aShows[$i][$eName] & " Game=" & $aShows[$i][$eGame] & " WeekDay=" & $aShows[$i][$eWeekDay] & " Date=" & $aShows[$i][$eDate] & " Time=" & $aShows[$i][$eTime] & " Duration=" & $aShows[$i][$eTimeSpan] & " Info=" & $aShows[$i][$eInfo])
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

Func _GetWochenPlan()
	; Open WinHTTP with specific User Agent String
	Local $vOpen = _WinHttpOpen($sUserAgentString)
	If @error Then
		_DebugWrite("Error Opening WinHTTP Handle")
		Return -1
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
		_DebugWrite("Error Opening WinHTTPConnect Handle")
		Return -1
	EndIf

	; Get the data from the Server
	Local $vRequest
	If $cfg_bUseSSL Then
		$vRequest = _WinHttpSimpleSSLRequest($vConnect, "GET", $sWochenPlanSubURL)
	Else
		$vRequest = _WinHttpSimpleRequest($vConnect, "GET", $sWochenPlanSubURL)
	EndIf
	If @error Then
		_DebugWrite("Unable To Read URL")
		Return -1
	EndIf

	; Get Next week data too
	Local $vRequestNextWeek
	If $cfg_bUseSSL Then
		$vRequestNextWeek = _WinHttpSimpleSSLRequest($vConnect, "GET", $sWochenPlanSubURLNext)
	Else
		$vRequestNextWeek = _WinHttpSimpleRequest($vConnect, "GET", $sWochenPlanSubURLNext)
	EndIf
	If @error Then
		_DebugWrite("Unable To Read URL")
		Return -1
	EndIf

	; Debug
	If $cfg_bDebug Then
		FileDelete("Page.htm")
		FileWrite("Page.htm", $vRequest)
	EndIf

	; Get week numbers
	$aCurrentWeekNum = StringRegExp($vRequest, '(?i)(?s)<h2>Woche (\d+)</h2>', $STR_REGEXPARRAYGLOBALMATCH)

	If Not @error Then
		$iWeekNumber = $aCurrentWeekNum[0]
		_DebugWrite("Week number: " & $iWeekNumber)
	Else
		_DebugWrite("Error getting week number of current week")
		_CreateCrashDump($vRequest)
	EndIf

	$aNextWeekNum = StringRegExp($vRequestNextWeek, '(?i)(?s)<h2>Woche (\d+)</h2>', $STR_REGEXPARRAYGLOBALMATCH)

	If IsArray($aNextWeekNum) Then
		; if they have diffrent week numbers, ew. are for diffrent weeks, join the together and handle them both
		If $iWeekNumber < $aNextWeekNum[0] Then
			_DebugWrite("Got next week data")
			$vRequest &= $vRequestNextWeek
		Else
			_DebugWrite("No next week data")
		EndIf
	Else
		_DebugWrite("Error getting week number of next week")
		_CreateCrashDump($vRequestNextWeek)
	EndIf

	Local $aArrayResult[0][$eMaxItems]
	Local $iCount = 0
	Local $sCurrentDay, $sCurrentDate

	; Get all days
	$aArray = StringRegExp($vRequest, '(?i)(?s)<div class="day.*?">(.*?)\s+</div>\s+</div>\s+</div>', $STR_REGEXPARRAYGLOBALMATCH)

	If Not @error Then
		For $i = 0 To UBound($aArray) - 1 Step 1

			; Get Day Info like Date and Date name
			$aDayInfo = StringRegExp($aArray[$i], '(?i)(?s)<div class="dateHeader">.*?<h3>(.*?)</h3><span>(.*?)</span>.*?</div>', $STR_REGEXPARRAYGLOBALMATCH)
			If Not @error Then
				$sCurrentDay = $aDayInfo[0]
				$sCurrentDate = $aDayInfo[1]
			Else
				_DebugWrite("Failed to get date info at iteration: " & $i)
				_CreateCrashDump($vRequest)
			EndIf

			$aShows = StringRegExp($aArray[$i], '(?i)(?s)<div id="show-" class="show">.*?<span class="scheduleTime">(.*?)</span>.*?<h4>(.*?)</h4>.*?<span class="game">(.*?)</span>.*?<div class="showInfo">(.*?)<span class="showDuration">(.*?)</span>.*?</div>.*?</div>.*?<span class="clear"></span>.*?</div>', $STR_REGEXPARRAYGLOBALMATCH)
			; 0 = ScheduleTime
			; 1 = Show Name
			; 2 = Game Name
			; 3 = ShowInfo not plain (live, premiere, none)
			; 4 = Duration

			If @error Then
				_CreateCrashDump($vRequest)
			EndIf

			For $j = 0 To UBound($aShows) - 1 Step 5
				ReDim $aArrayResult[UBound($aArrayResult) + 1][$eMaxItems]

				$aArrayResult[$iCount][$eDate] = $sCurrentDate
				$aArrayResult[$iCount][$eWeekDay] = $sCurrentDay
				$aArrayResult[$iCount][$eTime] = $aShows[$j]
				$aArrayResult[$iCount][$eName] = $aShows[$j + 1]
				$aArrayResult[$iCount][$eGame] = $aShows[$j + 2]
				$aArrayResult[$iCount][$eInfo] = _GetShowStatus($aShows[$j + 3])
				$aArrayResult[$iCount][$eTimeSpan] = $aShows[$j + 4]

				$iCount += 1
			Next
		Next
	Else
		_DebugWrite("Failed to get dates")
		_CreateCrashDump($vRequest)
	EndIf

	_DebugWrite("Total Number of shows found: " & UBound($aArrayResult))
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

Func _LoadConfig()
	$cfg_bAlertLiveOnly = __StringToBool(IniRead($sIniPath, "Config", "AlertLiveOnly", "True"))
	$cfg_asAlertNames = StringSplit(IniRead($sIniPath, "Config", "AlertNames", "Pen & Paper"), ",", $STR_ENTIRESPLIT + $STR_NOCOUNT)
	$cfg_bDebug = __StringToBool(IniRead($sIniPath, "Config", "Debug", Not @Compiled))
	$cfg_iDateDiff = Int(IniRead($sIniPath, "Config", "DateDiff", 3))
	$cfg_bUseSSL = __StringToBool(IniRead($sIniPath, "Config", "UseSSL", "False"))

	_DebugWrite("Config loaded!")
EndFunc   ;==>_LoadConfig


Func _CreateDefaultConfig()
	_DebugWrite("Creating default config")

	IniWrite($sIniPath, "Config", "AlertLiveOnly", "True")
	IniWrite($sIniPath, "Config", "AlerNames", "Pen & Paper")
	IniWrite($sIniPath, "Config", "DateDiff", 3)
	IniWrite($sIniPath, "Config", "UseSSL", "False")
EndFunc   ;==>_CreateDefaultConfig

Func _CreateCrashDump(Const ByRef $sRequest)
	Local $fHandle = FileOpen($sRootFolder & "\CrashDump-" & @YEAR & @MON & @MDAY & "-" & @HOUR & @MIN & @SEC & ".dump", $FO_OVERWRITE + $FO_CREATEPATH)

	FileWriteLine($fHandle, $sAppName & " V. " & $sVersion & $sVersionState & @CRLF) ; intentional blank line

	FileWriteLine($fHandle, "{: Current Config" & @CRLF & "$cfg_bAlertLiveOnly = " & String($cfg_bAlertLiveOnly))

	FileWriteLine($fHandle, "$cfg_asAlertNames size = " & UBound($cfg_asAlertNames))
	For $i = 0 To UBound($cfg_asAlertNames) - 1 Step 1
		FileWriteLine($fHandle, "$cfg_asAlertNames[" & $i & "] = " & $cfg_asAlertNames[$i])
	Next
	FileWriteLine($fHandle, "$cfg_bDebug = " & String($cfg_bDebug))
	FileWriteLine($fHandle, "$cfg_bUseSSL = " & String($cfg_bUseSSL))

	FileWriteLine($fHandle, "") ; Blank line

	Local $fHandleDLog = FileOpen($sDebugLogPath, $FO_READ)
	Local $sRead = FileRead($fHandleDLog)
	FileClose($fHandleDLog)

	FileWriteLine($fHandle, "{: Debug Log")
	FileWrite($fHandle, $sRead)

	FileWriteLine($fHandle, "{: Request")
	FileWrite($fHandle, $sRequest)

	FileClose($fHandle)

	_DebugWrite("Created crashdump")

	MsgBox($MB_OK, $sAppName, "Massiv problem see CrashDump file!")

	Exit -1
EndFunc   ;==>_CreateCrashDump

Func _IsDateInTheFuture(Const ByRef $Date)
	Local $aCompanents = StringRegExp($Date, '(?i)(\d+)\.\s*(.*?)\s*(\d+)', $STR_REGEXPARRAYGLOBALMATCH)
	; 0 = Day
	; 1 = Month (3 letters abr.)
	; 2 = year

	If @error Then
		_DebugWrite("Error extracting date info, input: " & $Date)
		_CreateCrashDump($Date)
	EndIf

	For $i = 0 To UBound($asMonthAbr) - 1 Step 1
		If $aCompanents[1] = $asMonthAbr[$i] Then
			$aCompanents[1] = $i + 1 ; +1 because our array starts with 0, but our month with 1
			ExitLoop
		EndIf
	Next

	If $aCompanents[0] > @MDAY Or $aCompanents[1] > @MON Or $aCompanents[2] > @YEAR Then
		If $cfg_iDateDiff > 0 Then
			Return _DateDiff("D", _NowCalcDate(), $aCompanents[2] & "/" & $aCompanents[1] & "/" & $aCompanents[0]) <= $cfg_iDateDiff
		Else
			; ignore time diffrence
			Return True
		EndIf
	Else
		Return False
	EndIf
EndFunc   ;==>_IsDateInTheFuture

Func _IsFirstLaunch()
	Return FileExists($sInstallPath) Or FileExists($sIniPath)
EndFunc   ;==>_IsFirstLaunch

Func __StringToBool(Const ByRef $sString)
	Return $sString = "True"
EndFunc   ;==>__StringToBool

Func _DebugWrite(Const ByRef $sDbgText)
	Local $fHandle = FileOpen($sDebugLogPath, $FO_APPEND + $FO_CREATEPATH)
	FileWrite($fHandle, "<" & @YEAR & "/" & @MON & "/" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & "." & @MSEC & "> " & $sDbgText & @CRLF)
	FileClose($fHandle)
EndFunc   ;==>_DebugWrite

Func _DebugErase()
	FileOpen($sDebugLogPath, $FO_OVERWRITE)
	FileClose($sDebugLogPath)
EndFunc   ;==>_DebugErase
