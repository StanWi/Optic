#include <Date.au3>
#include <File.au3>
#include <SQLite.au3>

Global $GMT = 8
Global $path = @ScriptDir & '\Export\BG\'
Global $sDbFile = IniRead("optic.ini", "Main", "Database", @ScriptDir & "\optic.db")
Local $aFileList = _FileListToArray($path, '*.csv')
If @error = 1 Then
	MsgBox($MB_SYSTEMMODAL, '', 'Path was invalid.')
	Exit
EndIf
If @error = 4 Then
	MsgBox($MB_SYSTEMMODAL, '', 'No file(s) were found.')
	Exit
EndIf
Local $i
For $i = 1 To $aFileList[0]
	ConsoleWrite($aFileList[$i] & @CRLF)
	_ExportOPT($aFileList[$i])
Next

Func _ExportOPT($file_name)
	Local $epoch = _EPOCH(FileGetTime($path & $file_name, 0, 1))
	Local $time = _EPOCH(StringMid($file_name, 17, 14))
	If $epoch > $time + 10 Or $epoch < $time - 60 Then ; Check file name and file change time. 56 second - current minute, 58 second - next.
		ConsoleWrite('File name and file change time missmatch.' & @CRLF)
		Return
	EndIf
	Local $aRecords, $i, $j
	_FileReadToArray($path & $file_name, $aRecords, 1, ',')
	insert_into_db_bg($sDbFile, "OpticBG", $aRecords, $epoch) ; time, neId, card, object, tx, rx, bias, temp, volt3, volt5, volt2, xfpt, tec, wave
	ConsoleWrite(@CRLF)
EndFunc   ;==>_ExportOPT

Func _EPOCH($time) ; Return number of seconds after EPOCH from file date YYYYMMDDHHMMSS
	Local $d = StringRegExpReplace($time, '(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})', '$1/$2/$3 $4:$5:$6')
	Return _DateDiff('s', '1970/01/01 00:00:00', $d) - 3600 * $GMT
EndFunc   ;==>_EPOCH

Func insert_into_db_bg($file, $table, $data, $epoch)
	Local $timer = TimerInit()
	_SQLite_Startup('sqlite3.dll', False, 1)
	If @error Then
		MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll Can't be Loaded!")
		Exit -1
	EndIf
	_SQLite_Open($file)
	$query = StringFormat('INSERT INTO %s VALUES ' & @CRLF, $table)
	For $i = 2 To $data[0][0]
		If $data[$i][3] <> '' Then
			; Insert data in table OpticBG 14 tabs,
			; data from ECI_NE, cardBG and objectBG used like Id,
			; values NA inserts like NULL.
			$query &= "(" & $epoch & ", (SELECT Id FROM ECI_NE WHERE Name LIKE '" & $data[$i][0] & "'), " & _
					"(SELECT id FROM cardBG WHERE card LIKE '" & $data[$i][1] & "'), " & _
					"(SELECT id FROM objectBG WHERE object LIKE '" & $data[$i][2] & "')"
			For $j = 3 To 12
				If $data[$i][$j] = 'NA' Then
					$data[$i][$j] = 'NULL'
				EndIf
				$query &= ", " & $data[$i][$j]
			Next
			$query &= "), " & @CRLF
		EndIf
	Next
	$query = StringTrimRight($query, 4)
	$query &= ';'
	_SQLite_Exec(-1, $query)
;~ 	ConsoleWrite($query & @CRLF)
	_SQLite_Close()
	_SQLite_Shutdown()
	ConsoleWrite('Query length ' & StringLen($query) & ' time insert ' & Round(TimerDiff($timer)) & ' ms, ' & Round(TimerDiff($timer) / $data[0][0] * 1000) & ' mcs one row' & @CRLF)
EndFunc   ;==>insert_into_db