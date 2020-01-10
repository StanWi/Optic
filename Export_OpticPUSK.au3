#include <Array.au3>
#include <Date.au3>
#include <File.au3>
#include <SQLite.au3>

Opt("MustDeclareVars", 1)

Local $readonly = False
Local $GMT = 8
Local $sDbFile = IniRead("optic.ini", "Main", "Database", @ScriptDir & "\optic.db")
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

For $i = 1 To $aNEList[0]
	ConsoleWrite($path & $aNEList[$i] & @CRLF)
	Local $aFileList = _FileListToArray($path & $aNEList[$i] & '\', '*')
	For $j = 1 To $aFileList[0]
		insert_into_db($sDbFile, 'opticPUSK', export_optic_pusk($path & $aNEList[$i] & '\' & $aFileList[$j], $aNEList[$i]), $readonly)
	Next
Next

Func export_optic_pusk($file, $ip)
	Local $aRecords, $i, $j, $data, $time, $request
	_FileReadToArray($file, $aRecords)
	Local $result[UBound($aRecords)][5]
	Local $k = 1
	For $i = 1 To $aRecords[0]
		If StringLeft($aRecords[$i], 1) = '*' Then
			$data = StringSplit($aRecords[$i], '[]=>;')
			If $data[9] <> '@' Then
				$time = epoch($data[2], $GMT)
				$j = 9
				While $j < $data[0]
					If $data[$j] <> 'SlotsState' Then
						If $data[$j] = 'PoutAmp' Or $data[$j] = 'PinRX' Or $data[$j] = 'PinLn' Or $data[$j] = 'Pin' Then
							$result[$k][0] = $time
							$result[$k][1] = $ip
							$result[$k][2] = $data[6]
							$result[$k][3] = $data[$j]
							$result[$k][4] = $data[$j + 1]
							$k += 1
						EndIf
					EndIf
					$j += 2
				WEnd
			EndIf
		EndIf
	Next
	$result[0][0] = $k - 1
;~ 	_ArrayDisplay($result)
	Return $result
EndFunc   ;==>export_optic_pusk

Func epoch($date, $GMT)
	Local $d = StringSplit($date, '/ ')
	If $d[0] <> 4 Then
		ConsoleWrite('Error _EPOCH(): ' & $date & @CRLF)
		Exit
	EndIf
	Return _DateDiff('s', '1970/01/01 00:00:00', $d[3] & '/' & $d[2] & '/' & $d[1] & ' ' & $d[4]) - 3600 * $GMT
EndFunc   ;==>epoch

Func insert_into_db($file, $table, $data, $readonly) ; time|neId|objectId|paramId|value
	Local $timer = TimerInit()
	_SQLite_Startup('sqlite3.dll', False, 1)
	If @error Then
		MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll Can't be Loaded!")
		Exit -1
	EndIf
	_SQLite_Open($file)
	Local $query = StringFormat('INSERT INTO %s VALUES ', $table)
	For $i = 1 To $data[0][0]
		$query &= StringFormat("(%u, (SELECT id FROM nePUSK WHERE ip = '%s'), (SELECT id FROM objectPUSK WHERE object = '%s'), " & _
				"(SELECT id FROM paramPUSK WHERE param = '%s'), %g), ", $data[$i][0], $data[$i][1], $data[$i][2], $data[$i][3], $data[$i][4])
	Next
	$query = StringTrimRight($query, 2)
	$query &= ';'
;~ 	ConsoleWrite($query & @CRLF)
	If Not $readonly Then _SQLite_Exec(-1, $query)
	_SQLite_Close()
	_SQLite_Shutdown()
	ConsoleWrite(StringFormat('Query length %u time insert %u ms, %u mcs one row' & @CRLF, StringLen($query), Round(TimerDiff($timer)), Round(TimerDiff($timer) / $data[0][0] * 1000)))
EndFunc   ;==>insert_into_db
