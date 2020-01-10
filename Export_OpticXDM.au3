#include <Array.au3>
#include <File.au3>
#include <SQLite.au3>

$path = @ScriptDir & '\Export\XDM\'
Global $sDbFile = IniRead("optic.ini", "Main", "Database", @ScriptDir & "\optic.db") ; Файл базы данных.

$aFileList = _FileListToArray($path)
If @error = 1 Then
	MsgBox($MB_SYSTEMMODAL, "", "Path was invalid.")
	Exit
EndIf
If @error = 4 Then
	MsgBox($MB_SYSTEMMODAL, "", "No file(s) were found.")
	Exit
EndIf

_ArrayDisplay($aFileList)

Global $percent = 0
;~ Global $tabs = ['time', 'neId', 'objectId', 'paramId', 'last', 'min', 'max']

For $i = 1 To $aFileList[0]
	ConsoleWrite($path & $aFileList[$i] & ' ')
	export_opt($path & $aFileList[$i], $i, $aFileList[0])
Next

Func export_opt($file_name, $iFile, $nFile)
	TraySetToolTip('Файл ' & $iFile & ' из ' & $nFile & @CRLF & $percent & ' %')

	$file = FileOpen($file_name, 512) ; Use ANSI reading and writing mode.
	$hex = Hex(Binary(FileRead($file)))
	FileClose($file)

	Local $num = StringInStr($hex, '0A', 2, 1) + 2 ; Ищем первое вхождение '0A', быстрый поиск без учёта регистра
	Local $object = ''
	Local $timer ; Таймер подсказки в трее
	Local $value[3]
	Local $k = 0
	Local $result[Round(FileGetSize($file_name) / 30)][7]

	$timer = TimerInit() ; Инициализация таймена для подсказки в трее
	While $num < StringLen($hex)
		If _rByteToDec($hex, $num, 2) <> 2 Then
			$num = $num + 92 ; Skip data with "Disconnected NE 0x0A...00000000"
			ConsoleWrite('Skip data with "Disconnected NE 0x0A...00000000"' & @CRLF)
			ContinueLoop
		EndIf
		$time = _rByteToDec($hex, $num + 44, 4) ; time
		$neId = _rByteToDec($hex, $num + 8, 2) ; neId
		$object = _rByteToDec($hex, $num + 16, 2) ; objectId
;~ 		$object = '''[#' & _rByteToDec($hex, $num, 2) & '/' & _rByteToDec($hex, $num + 4, 2) & ':' & _rByteToDec($hex, $num + 8, 2) & '/' & _rByteToDec($hex, $num + 12, 2) & ':' & _rByteToDec($hex, $num + 16, 2) & ']''' ; object
		$count = _rByteToDec($hex, $num + 52, 2)
		For $i = 0 To $count / 3 - 1
			$paramId = _rByteToDec($hex, $num + 56 + $i * 52, 2) ; paramId
			For $j = 0 To 2
				$absValue = _rByteToDec($hex, $num + 60 + $i * 52 + $j * 16, 2)
				$minus = _rByteToDec($hex, $num + 64 + $i * 52 + $j * 16, 2)
				$idn = _rByteToDec($hex, $num + 68 + $i * 52 + $j * 16, 2)
				$degree = _rByteToDec($hex, $num + 72 + $i * 52 + $j * 16, 2)
				$value[$j] = $absValue / $degree
				If $minus = 1 Then
					$value[$j] = $value[$j] * -1
				EndIf
			Next
			$k += 1
			$result[$k][0] = $time
			$result[$k][1] = $neId
			$result[$k][2] = $object
			$result[$k][3] = $paramId
			$result[$k][4] = $value[0]
			$result[$k][5] = $value[1]
			$result[$k][6] = $value[2]
;~ 			$query = 'INSERT INTO OpticECI (time, neId, object, paramId, last, min, max) VALUES(' & $time & ', ' & $neId & ', ' & $object & ', ' & $paramId & ', ' & $value[0] & ', ' & $value[1] & ', ' & $value[2] & ');'
;~ 			ConsoleWrite($query & @CRLF)
;~ 			_SQLite_Exec(-1, $query)
		Next
		$num = $num + 14 * 4 + $count / 3 * 13 * 4

;~ 		TraySetToolTip('Файл ' & $iFile & ' из ' & $nFile & @CRLF & $percent + Round(($num / StringLen($hex) * 100) / $nFile, 2) & ' %, время внесения записи ' & Round(TimerDiff($timer), 0) & ' мс')
	WEnd
	$result[0][0] = $k
	ConsoleWrite('record in ' & Round(TimerDiff($timer) / $k * 1000) & ' mcs, total ' & $k & ' records. ')
;~ 	_ArrayDisplay($result)
	insert_into_db($sDbFile, 'optic_xdm', $result)
	$percent = Round($iFile / $nFile * 100, 2)
EndFunc   ;==>export_opt

Func _rByteToDec($string, $k, $n) ; Преобразование $n байтов в обратном порядке в десятичное число
	Local $subString = ''
	For $i = $n - 1 To 0 Step -1
		$subString = $subString & StringMid($string, $k + $i * 2, 2)
	Next
	Local $result = Dec($subString)
	Return ($result)
EndFunc   ;==>_rByteToDec

Func insert_into_db($file, $table, $data)
	Local $timer = TimerInit()
	_SQLite_Startup('sqlite3.dll', False, 1)
	If @error Then
		MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll Can't be Loaded!")
		Exit -1
	EndIf
	_SQLite_Open($file)
	$query = StringFormat('INSERT INTO %s VALUES ', $table)
	For $i = 1 To $data[0][0]
		$query &= StringFormat('(%u, %u, %u, %u, %g, %g, %g), ', $data[$i][0], $data[$i][1], $data[$i][2], $data[$i][3], $data[$i][4], $data[$i][5], $data[$i][6])
	Next
	$query = StringTrimRight($query, 2)
	$query &= ';'
	_SQLite_Exec(-1, $query)
;~ 	ConsoleWrite($query & @CRLF)
	_SQLite_Close()
	_SQLite_Shutdown()
	ConsoleWrite('Query length ' & StringLen($query) & ' time insert ' & Round(TimerDiff($timer)) & ' ms, ' & Round(TimerDiff($timer) / $data[0][0] * 1000) & ' mcs one row' & @CRLF)
EndFunc   ;==>insert_into_db
