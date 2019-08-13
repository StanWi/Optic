#include <Array.au3>
#include <Date.au3>
#include <File.au3>
#include <SQLite.au3>

Global $GMT = 8
Global $sDbFile = IniRead("optic.ini", "Main", "Database", @ScriptDir & "\optic.db") ; Файл базы данных.
$path = @ScriptDir & '\Export\ZTE\'
$dir = _FileListToArray($path, '*', $FLTA_FOLDERS)
If @error = 1 Then
	MsgBox($MB_SYSTEMMODAL, "", "Path was invalid.")
	Exit
EndIf
If @error = 4 Then
	MsgBox($MB_SYSTEMMODAL, "", "No file(s) were found.")
	Exit
EndIf
$file = '\BNPM.dbo.PMP_04701.dat' ; 15 min
;~ $file = '\BNPM.dbo.PMP_04701_D.dat' ; Day file
$offset = 0 ; -1 for Day file, 0 for 15 min

Dim $data

_SQLite_Startup('sqlite3.dll', False, 1)
If @error Then
	MsgBox($MB_SYSTEMMODAL, 'SQLite Error', 'SQLite3.dll Can''t be Loaded!')
	Exit -1
EndIf
_SQLite_Open($sDbFile)

For $i = 1 To $dir[0]
	ConsoleWrite($path & $dir[$i] & $file & @CRLF)
	_FileReadToArray($path & $dir[$i] & $file, $data, $FRTA_COUNT, @TAB)
	$percent = 0.1
;~ 	_ArrayDisplay($data)
	$timer = TimerInit()
	$value_length = 1
	For $j = 1 To $data[0][0]
		If StringRight($data[$j][8 + $offset], 10) = '{/p=401_1}' Or StringRight($data[$j][8 + $offset], 10) = '{/p=402_1}' Then
			$value_length += 1
		EndIf
	Next
	Dim $value[$value_length][5]
	$k = 1
	For $j = 1 To $data[0][0]
		Switch StringRight($data[$j][8 + $offset], 10)
			Case '{/p=401_1}'
				$value[$k][0] = _EPOCH($data[$j][3])
				$value[$k][1] = _split($data[$j][8 + $offset], 'ne')
				$value[$k][2] = _split($data[$j][8 + $offset], 'slot')
				$value[$k][3] = '401_1'
				$value[$k][4] = Number($data[$j][12 + $offset])
				$k += 1
			Case '{/p=402_1}'
				$value[$k][0] = _EPOCH($data[$j][3])
				$value[$k][1] = _split($data[$j][8 + $offset], 'ne')
				$value[$k][2] = _split($data[$j][8 + $offset], 'slot')
				$value[$k][3] = '402_1'
				$value[$k][4] = Number($data[$j][16 + $offset])
				$k += 1
		EndSwitch
		$value[0][0] = $k - 1
		If $j / $data[0][0] > $percent Then
			$percent += 0.1
			ConsoleWrite('.')
		EndIf
	Next
	print('')
	print('Время генерации списка ' & TimerDiff($timer))
	print('Длина списка $value = ' & $value[0][0])
;~ 	_ArrayDisplay($value)
	For $j = 0 To Floor($value[0][0] / 500)
		ConsoleWrite('<')
		_SQLite_Exec(-1, _request($value, $j))
		ConsoleWrite('>')
	Next
	print('')
Next

_SQLite_Close()
_SQLite_Shutdown()

Func _split($string, $mode = 'ne')
	Local $data = StringSplit($string, '{=}/')
	Local $result
	Switch $mode
		Case 'ne'
			$result = $data[2]
		Case 'slot'
			$result = '[' & $data[7] & '-' & $data[9] & '-' & $data[11] & ']'
		Case 'param'
			$result = $data[16]
	EndSwitch
	Return $result
EndFunc   ;==>_split

Func _EPOCH($time) ;Возвращает количество секунд после EPOCH от даты изменения файла YYYYMMDDHHMMSS
	Local $d = StringRegExpReplace($time, '(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}).000', '$1/$2/$3 $4:$5:$6')
	Return _DateDiff('s', '1970/01/01 00:00:00', $d) - 3600 * $GMT
EndFunc   ;==>_EPOCH

Func _request($value, $step = 0) ;500 строк
	If $value[0][0] - 500 * $step > 1 Then
		Local $request = 'INSERT INTO opticZTE' & @CRLF
		Local $i
		$request &= 'SELECT ' & $value[1 + 500 * $step][0] & ' AS time, ' & $value[1 + 500 * $step][1] & ' AS neId, "' & $value[1 + 500 * $step][2] & '" AS slot, "' & $value[1 + 500 * $step][3] & '" AS param, ' & $value[1 + 500 * $step][4] & ' AS value' & @CRLF
		For $i = 2 + 500 * $step To 500 * ($step + 1)
			$request &= 'UNION SELECT ' & $value[$i][0] & ', ' & $value[$i][1] & ', "' & $value[$i][2] & '", "' & $value[$i][3] & '", ' & $value[$i][4] & @CRLF
			If $i >= $value[0][0] Then
				ExitLoop
			EndIf
		Next
		$request &= ';'
	ElseIf $value[0][0] - 500 * $step = 1 Then
		$request = 'INSERT INTO opticZTE (time, neId, slot, param, value) VALUES ' & $value[1 + 500 * $step][0] & ', ' & $value[1 + 500 * $step][1] & ', "' & $value[1 + 500 * $step][2] & '", "' & $value[1 + 500 * $step][3] & '", ' & $value[1 + 500 * $step][4] & ';'
		ConsoleWrite('Bingo' & @CRLF)
	Else
		MsgBox(0, '', 'Error')
	EndIf
	Return $request
EndFunc   ;==>_request

Func print($string)
	ConsoleWrite($string & @CRLF)
EndFunc   ;==>print
