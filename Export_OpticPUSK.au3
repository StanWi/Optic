#include <Array.au3>
#include <Date.au3>
#include <File.au3>
#include <SQLite.au3>

Global $GMT = 8
Local $path = @ScriptDir & '\Export\PUSK\'
Local $aNEList = _FileListToArray($path, '*')
If @error = 1 Then
	MsgBox($MB_SYSTEMMODAL, "", "Path was invalid.")
	Exit
EndIf
If @error = 4 Then
	MsgBox($MB_SYSTEMMODAL, "", "No file(s) were found.")
	Exit
EndIf

Global $sDbFile = IniRead("optic.ini", "Main", "Database", @ScriptDir & "\optic.db") ; Файл базы данных.
_SQLite_Startup('sqlite3.dll', False, 1)
If @error Then
	MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll Can't be Loaded!")
	Exit -1
EndIf
_SQLite_Open($sDbFile)
For $i = 1 To $aNEList[0]
	ConsoleWrite(@CRLF & $path & $aNEList[$i] & @CRLF)
	Local $aFileList = _FileListToArray($path & $aNEList[$i] & '\', '*')
	For $j = 1 To $aFileList[0]
		ConsoleWrite('.')
		_ExportOpticPUSK($path & $aNEList[$i] & '\' & $aFileList[$j], $aNEList[$i])
	Next
Next
_SQLite_Close()
_SQLite_Shutdown()

Func _ExportOpticPUSK($file, $ip)
	Local $aRecords, $i, $j, $data, $time, $request
	_FileReadToArray($file, $aRecords)
	For $i = 1 To $aRecords[0]
		If StringLeft($aRecords[$i], 1) = '*' Then
			$data = StringSplit($aRecords[$i], '[]=>;')
			If $data[9] <> '@' Then
				$time = _EPOCH($data[2])
				$j = 9
				While $j < $data[0]
					If $data[$j] <> 'SlotsState' Then
						If $data[$j] = 'PoutAmp' Or $data[$j] = 'PinRX' Or $data[$j] = 'PinLn' Or $data[$j] = 'Pin' Then
							$request = "INSERT INTO opticPUSK (time, neId, objectId, paramId, value)" & _
									" VALUES (" & $time & ", (SELECT id FROM nePUSK WHERE ip LIKE '" & $ip & "'), " & _
									"(SELECT id FROM objectPUSK WHERE object LIKE '" & $data[6] & "'), " & _
									"(SELECT id FROM paramPUSK WHERE param LIKE '" & $data[$j] & "'), " & $data[$j + 1] & ");"
							_SQLite_Exec(-1, $request)
						EndIf
					EndIf
					$j += 2
				WEnd
			EndIf
		EndIf
	Next
EndFunc   ;==>_ExportOpticPUSK

Func _EPOCH($date)
	Local $d = StringSplit($date, '/ ')
	If $d[0] <> 4 Then
		ConsoleWrite('Error _EPOCH(): ' & $date & @CRLF)
		Exit
	EndIf
	Return _DateDiff('s', '1970/01/01 00:00:00', $d[3] & '/' & $d[2] & '/' & $d[1] & ' ' & $d[4]) - 3600 * $GMT
EndFunc   ;==>_EPOCH
