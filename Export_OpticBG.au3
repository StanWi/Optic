#include <Date.au3>
#include <File.au3>
#include <SQLite.au3>

Global $GMT = 8
Global $path = @ScriptDir & '\Export\BG\' ;����� � ������� LaserPerformanceYYYYMMDDHHMMSS.csv.
Global $sDbFile = IniRead("optic.ini", "Main", "Database", @ScriptDir & "\optic.db") ; ���� ���� ������.
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
	If $epoch > $time + 10 Or $epoch < $time - 60 Then ;�������� ������������ ���� ��������� ����� ��� ��������. 56 ������� - ������� ������, 58 ������� - ���������.
		ConsoleWrite('�� ��������� ��� ����� � ����� ��� ���������.' & @CRLF) ;��������, epoch 1458779160, time 1458779209. 2374 4751
		Return
	EndIf
	Local $aRecords, $i, $j
	_FileReadToArray($path & $file_name, $aRecords, 1, ',')
	_SQLite_Startup('sqlite3.dll', False, 1)
	If @error Then
		MsgBox($MB_SYSTEMMODAL, 'SQLite Error', 'SQLite3.dll Can''t be Loaded!')
		Exit -1
	EndIf
	_SQLite_Open($sDbFile)
	Local $percent = 0.1 ;����������� ��� ����������� ���� ���������� �����
	For $i = 2 To $aRecords[0][0]
		If $aRecords[$i][3] <> '' Then
			;������ ������ � ������� OpticBG ����� 14 ��������,
			;������ �� ��� ������ ECI_NE, cardBG � objectBG ������������ � �������� ���������������,
			;�������� NA �������� ��� NULL.
			$request = "INSERT INTO OpticBG (time, neId, card, object, tx, rx, bias, temp, volt3, volt5, volt2, xfpt, tec, wave)" & _
					" VALUES (" & $epoch & ", (SELECT Id FROM ECI_NE WHERE Name LIKE '" & $aRecords[$i][0] & "'), " & _
					"(SELECT id FROM cardBG WHERE card LIKE '" & $aRecords[$i][1] & "'), " & _
					"(SELECT id FROM objectBG WHERE object LIKE '" & $aRecords[$i][2] & "')"
			For $j = 3 To 12
				If $aRecords[$i][$j] = 'NA' Then
					$aRecords[$i][$j] = 'NULL'
				EndIf
				$request &= ", " & $aRecords[$i][$j]
			Next
			$request &= ");"
			;ConsoleWrite($request & @CRLF)
			_SQLite_Exec(-1, $request)
		EndIf
		If $i / $aRecords[0][0] >= $percent Then ;����������� �������� ��������� �������� � ����
			ConsoleWrite('.')
			$percent += 0.1
		EndIf
	Next
	_SQLite_Close()
	_SQLite_Shutdown()
	ConsoleWrite(@CRLF)
EndFunc   ;==>_ExportOPT

Func _EPOCH($time) ;���������� ���������� ������ ����� EPOCH �� ���� ��������� ����� YYYYMMDDHHMMSS
	Local $d = StringRegExpReplace($time, '(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})', '$1/$2/$3 $4:$5:$6')
	Return _DateDiff('s', '1970/01/01 00:00:00', $d) - 3600 * $GMT
EndFunc   ;==>_EPOCH
