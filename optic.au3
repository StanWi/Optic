#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_UseX64=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;15.12.2017 � ��������� ��������� ��������� �������� ������������� � �����.
;21.12.2017 ����� ���������� ������ "�� �������" � "�� ��������"
#include <Array.au3>
#include <Date.au3>
#include <File.au3>
#include <GraphGDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <DateTimeConstants.au3>
#include <SQLite.au3>
#include <ListViewConstants.au3>
#include <GuiListView.au3>
#include <GuiImageList.au3>;23.01.2017 ��� ������ � ������
#include <FileConstants.au3>;23.01.2017 ��� ������ ����

Opt('GUIOnEventMode', 1)

Global $Graph, $ini, $data_path, $journal, $ne_list, $card_list, $param_list, $checkLimitHigh, $checkLimitCritical, $checkLimitWarning
Global $aLinkName
Dim $work_files[1]
Global $aValue
; ===== ������ ���������� � ��� ���� =====
Global $enableLogFile = False
$company = IniRead("optic.ini", "Main", "Company", "Company")
Global $db_file = IniRead("optic.ini", "Main", "Database", @ScriptDir & "\optic.db")
Global $GMT = 8

; ������� ����
Global $GUI = GUICreate(StringFormat('������� ����������� ��������� � ���������� �������� - %s', $company), 1000, 650)
GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
; ���������
GUICtrlCreateLabel('������ �:', 10, 10, 100)
$date_start = GUICtrlCreateDate(_DateAdd('M', -1, _NowCalcDate()), 10, 35, 100, -1, $DTS_SHORTDATEFORMAT)
GUICtrlSetOnEvent($date_start, "_DateCheckStart")
GUICtrlCreateLabel('��:', 120, 10, 100)
$date_stop = GUICtrlCreateDate(_NowCalcDate(), 120, 35, 100, -1, $DTS_SHORTDATEFORMAT)
GUICtrlSetOnEvent($date_stop, "_DateCheckStop")
; ���������
GUICtrlCreateLabel('�������:', 10, 70, 100)
Global $label_sort = GUICtrlCreateLabel("�� ��������", 120, 70, 100, 21, 0x0002)
GUICtrlSetColor(-1, 0x0000ff)
GUICtrlSetCursor(-1, 0)
GUICtrlSetOnEvent($label_sort, "_ListSort")
Global $topo_list = GUICtrlCreateCombo('', 10, 95, 210)
GUICtrlSetData($topo_list, _DataLinkList())
GUICtrlSetOnEvent($topo_list, "_DrawGraph")
; �����
Global $waitLabel = GUICtrlCreateLabel('', 10, 150, 500, 25)
; ���� ����������
Global $ListView = GUICtrlCreateListView('', 240, 10, 750, 105)
;�����������                    |����, ��|�����, ��|dA, ��|���, ��|�����������
_GUICtrlListView_InsertColumn($ListView, 0, "�����������", 230)
_GUICtrlListView_InsertColumn($ListView, 1, "����, ��", 70)
_GUICtrlListView_InsertColumn($ListView, 2, "�����, ��", 70)
_GUICtrlListView_InsertColumn($ListView, 3, "dA, ��", 70)
_GUICtrlListView_InsertColumn($ListView, 4, "���, ��", 70)
_GUICtrlListView_InsertColumn($ListView, 5, "�����������", 180)
; �������� ����
GUISetState()

While 1 ;�������� ����. ������ ��������. 100 ��.
	Sleep(100)
WEnd

Func _DateCheckStart()
	Local $start = StringRegExpReplace(GUICtrlRead($date_start), '(\d+)\.(\d+)\.(\d+)', '$3/$2/$1')
	Local $stop = StringRegExpReplace(GUICtrlRead($date_stop), '(\d+)\.(\d+)\.(\d+)', '$3/$2/$1')
	If _DateDiff('D', $start, $stop) < 0 Then
		GUICtrlSetData($date_stop, $start)
	EndIf
EndFunc   ;==>_DateCheckStart

Func _DateCheckStop()
	Local $start = StringRegExpReplace(GUICtrlRead($date_start), '(\d+)\.(\d+)\.(\d+)', '$3/$2/$1')
	Local $stop = StringRegExpReplace(GUICtrlRead($date_stop), '(\d+)\.(\d+)\.(\d+)', '$3/$2/$1')
	If _DateDiff('D', $start, $stop) < 0 Then
		GUICtrlSetData($date_start, $stop)
	EndIf
EndFunc   ;==>_DateCheckStop

Func _DrawGraph()
	_GraphGDIPlus_Delete($GUI, $Graph)
	_GUICtrlListView_DeleteAllItems($ListView)
	GUICtrlSetData($waitLabel, '����������, ���������...')
	Local $link = GUICtrlRead($topo_list)
	Local $ne_list = StringSplit($link, '. ', 1)
	If $ne_list[0] = 1 Then
		$link = $ne_list[1]
	ElseIf $ne_list[0] = 2 Then
		$link = $ne_list[2]
	Else
		MsgBox(0, '��������� - ������', '������ � �������� �����.')
		Return
	EndIf
	Local $ne_list = StringSplit($link, ' - ', 1)
	;_ArrayDisplay($ne_list)
	If $ne_list[0] <> 2 Then ;�������� ������������ ����������� �����
		MsgBox(0, '��������� - ������', '������ � �������� �����.')
		Return
	EndIf
	Local $start = _EPOCH(StringRegExpReplace(GUICtrlRead($date_start), '(\d+)\.(\d+)\.(\d+)', '$1/$2/$3') & ' 00:00:00')
	Local $stop = _EPOCH(StringRegExpReplace(GUICtrlRead($date_stop), '(\d+)\.(\d+)\.(\d+)', '$1/$2/$3') & ' 00:00:00') + 24 * 3600
	Local $i = 1
	Local $k = 0
	Local $aResult, $iRows, $iColumns, $iRval, $aData, $iOpticRows, $aDataRaw
	_SQLite_Startup('sqlite3.dll', False, 1)
	If @error Then
		MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll Can't be Loaded!")
		Exit -1
	EndIf
	;ConsoleWrite("_SQLite_LibVersion=" & _SQLite_LibVersion() & @CRLF)
	_SQLite_Open($db_file)
	; Query
	$iRval = _SQLite_GetTable2d(-1, "SELECT * FROM topology WHERE (neSrc LIKE '" & $ne_list[1] & "%' AND neSnk LIKE '" & $ne_list[2] & "%') OR (neSrc LIKE '" & $ne_list[2] & "%' AND neSnk LIKE '" & $ne_list[1] & "%');", $aResult, $iRows, $iColumns)
	If $iRval = $SQLITE_OK Then
		;_SQLite_Display2DResult($aResult)
		;GUICtrlSetData($waitLabel,$iRows)
		If $iRows > 0 Then
			Dim $aValue[Round(($stop - $start) / 900 + 2000, 0)][$iRows * 2] ; +2000 array range exceeded 20.12.2018 on 2 years request
			;_ArrayDisplay($aResult)
			Dim $aLinkName[1][2]
			For $i = 1 To $iRows
				Local $timer = TimerInit()
				$attenuation = $aResult[$i][10] ;�������� ��������� �� �����������. ������������� ����� - �������� ���������. ������������� - ��������.
				GUICtrlSetData($waitLabel, '����������, ���������... ������ ' & $i & ' �� ' & $iRows)
				Switch $aResult[$i][1] ;�������� ��� ������������
					Case 'eciXdm'
						$request = "SELECT time, neId, last FROM optic_xdm WHERE time BETWEEN " & $start & " AND " & $stop & " " & _
								"AND ((neId = (SELECT Id FROM ECI_NE WHERE Name = '" & $aResult[$i][2] & "') " & _
								"AND objectId = (SELECT objectId FROM ECI_Object WHERE objectName = '" & $aResult[$i][3] & "') " & _
								"AND paramId = 271)" & _
								"OR (neId = (SELECT Id FROM ECI_NE WHERE Name = '" & $aResult[$i][5] & "') " & _
								"AND objectId = (SELECT objectId FROM ECI_Object WHERE objectName = '" & $aResult[$i][6] & "') " & _
								"AND paramId = 280));"
					Case 'eciBg'
						$tmp = StringSplit($aResult[$i][3], ' GE-ETY port ', 1)
						If @error = 1 Then
							$tmp = StringSplit($aResult[$i][3], ' oPort ', 1)
							$object1 = 'oPort ' & $tmp[2]
						Else
							$object1 = 'GE-ETY port ' & $tmp[2]
						EndIf
						$card1 = $tmp[1]
						$tmp = StringSplit($aResult[$i][6], ' GE-ETY port ', 1)
						If @error = 1 Then
							; ��������� ��� 18.10.2016, ������ $aResult[$i][6] ���� $aResult[$i][3]
							$tmp = StringSplit($aResult[$i][6], ' oPort ', 1)
							$object2 = 'oPort ' & $tmp[2]
						Else
							$object2 = 'GE-ETY port ' & $tmp[2]
						EndIf
						$card2 = $tmp[1]
						$request = "SELECT time, neId, tx FROM OpticBG WHERE time BETWEEN " & $start & " AND " & $stop & " " & _
								"AND neId = (SELECT Id FROM ECI_NE WHERE Name = '" & $aResult[$i][2] & "') " & _
								"AND card = (SELECT id FROM cardBG WHERE card LIKE '" & $card1 & "') " & _
								"AND object = (SELECT id FROM objectBG WHERE object LIKE '" & $object1 & "-SFP') " & _
								"UNION SELECT time, neId, rx FROM OpticBG WHERE time BETWEEN " & $start & " AND " & $stop & " " & _
								"AND neId = (SELECT Id FROM ECI_NE WHERE Name = '" & $aResult[$i][5] & "') " & _
								"AND card = (SELECT id FROM cardBG WHERE card LIKE '" & $card2 & "') " & _
								"AND object = (SELECT id FROM objectBG WHERE object LIKE '" & $object2 & "-SFP');"
					Case 'pusk'
						$request = "SELECT time, neId, value FROM opticPUSK WHERE time BETWEEN " & $start & " AND " & $stop & " " & _
								"AND ((neId = (SELECT id FROM nePUSK WHERE name LIKE '" & $aResult[$i][2] & "') " & _
								"AND objectId = (SELECT id FROM objectPUSK WHERE object LIKE '" & $aResult[$i][3] & "') " & _
								"AND paramId = (SELECT id FROM paramPUSK WHERE param LIKE '" & $aResult[$i][4] & "')) " & _
								"OR (neId = (SELECT id FROM nePUSK WHERE name LIKE '" & $aResult[$i][5] & "') " & _
								"AND objectId = (SELECT id FROM objectPUSK WHERE object LIKE '" & $aResult[$i][6] & "') " & _
								"AND paramId = (SELECT id FROM paramPUSK WHERE param LIKE '" & $aResult[$i][7] & "')));"
					Case 'zte'
						$request = "SELECT time, neId, value FROM opticZTE WHERE time BETWEEN " & $start & " AND " & $stop & " " & _
								"AND ((neId = (SELECT id FROM neZTE WHERE ne LIKE '" & $aResult[$i][2] & "') " & _
								"AND slot LIKE '" & $aResult[$i][3] & "' " & _
								"AND param LIKE '" & $aResult[$i][4] & "') " & _
								"OR (neId = (SELECT id FROM neZTE WHERE ne LIKE '" & $aResult[$i][5] & "') " & _
								"AND slot LIKE '" & $aResult[$i][6] & "' " & _
								"AND param LIKE '" & $aResult[$i][7] & "'));"
				EndSwitch
				ConsoleWrite($request & @CRLF)
				$timer_request = TimerInit()
				$iRval = _SQLite_GetTable2d(-1, $request, $aDataRaw, $iOpticRows, $iColumns)
				$timer_request_time = TimerDiff($timer_request)
				$timer_request_time_per_item = Round($timer_request_time / $iOpticRows * 1000)
				$timer_calc = TimerInit()
				ConsoleWrite('������� ����� �� ������ ������ ' & Round(TimerDiff($timer)) & ' ����������.' & @CRLF)
				;_ArrayDisplay($aDataRaw)
				_ArraySort($aDataRaw, 0, 1)
				;_ArrayDisplay($aDataRaw)
				ConsoleWrite('���-�� ����� ' & $iOpticRows & @CRLF)
				$line = 0
				Dim $aData[$iOpticRows][2]
				$timer = TimerInit()
				For $j = 1 To $iOpticRows - 1
					If ($aDataRaw[$j][1] <> $aDataRaw[$j + 1][1]) And ($aDataRaw[$j + 1][0] - $aDataRaw[$j][0] < 450) Then
						#cs ;Debug
							If $j > 4600 Then
							ConsoleWrite('$aDataRaw[' & $j & '][0] = ' & $aDataRaw[$j][0] & ', $aDataRaw[' & $j & ' + 1][0] = ' & $aDataRaw[$j + 1][0] & ', $aDataRaw[' & $j & '][1] = ' & $aDataRaw[$j][1] & ', $aDataRaw[' & $j & ' + 1][1] = ' & $aDataRaw[$j + 1][1] & @CRLF)
							EndIf
						#ce ;Stop debug
						$line += 1
						$aData[$line][0] = ($aDataRaw[$j + 1][0] + $aDataRaw[$j][0]) / 2
						$aData[$line][1] = Abs($aDataRaw[$j + 1][2] - $aDataRaw[$j][2]) + $attenuation ;��������� �������� ���������
					EndIf
				Next
				ConsoleWrite('������ ������� ������� ������ ' & Round(TimerDiff($timer)) & ' ����������.' & @CRLF)
				ConsoleWrite('��������� ������ ������� ' & Round(TimerDiff($timer) / $iOpticRows * 1000) & ' �����������.' & @CRLF)
				$iOpticRows = $line
				;_ArrayDisplay($aData)
				If $iRval = $SQLITE_OK Then
					;_SQLite_Display2DResult($aResult)
					;_ArrayDisplay($aData)
					If $iOpticRows > 0 Then
						$aValue[0][$k] = $iOpticRows
						$aValue[0][1] = $k / 2 + 1
						_ArrayAdd($aLinkName, $aResult[$i][2] & ' > ' & $aResult[$i][5] & '|' & $aResult[$i][9])
						For $j = 1 To $iOpticRows
							$aValue[$j][$k] = $aData[$j][0]
							$aValue[$j][$k + 1] = $aData[$j][1]
						Next
						$k += 2
					EndIf
				Else
					MsgBox($MB_SYSTEMMODAL, "SQLite Error: " & $iRval, _SQLite_ErrMsg())
				EndIf
				$timer_calc_time = TimerDiff($timer_calc)
				$timer_calc_time_per_item = Round($timer_calc_time / $iOpticRows * 1000)
				ConsoleWrite('' & @CRLF)
				ConsoleWrite('==============================' & @CRLF)
				ConsoleWrite('����� ������� ' & Round($timer_request_time / 1000) & ' c, ���� ������ �� ' & $timer_request_time_per_item & ' ���' & @CRLF)
				ConsoleWrite('����� ���������� ' & Round($timer_calc_time) & ' ��, ���� ������ �� ' & $timer_calc_time_per_item & ' ���' & @CRLF)
				ConsoleWrite('==============================' & @CRLF)
				ConsoleWrite('' & @CRLF)
			Next
		EndIf
	Else
		MsgBox($MB_SYSTEMMODAL, "SQLite Error: " & $iRval, _SQLite_ErrMsg())
	EndIf
;~ 	"SELECT time, last FROM OpticECI " & _
;~ 	"WHERE time BETWEEN " & $start & " AND " & $stop & " " & _
;~ 	"AND neId = (SELECT Id FROM ECI_NE WHERE Name = 'TEC-11') " & _
;~ 	"AND object LIKE '%:' || (SELECT objectId FROM ECI_Object WHERE objectName = 'M9 OM_OFA_P 1') || ']' " & _
;~ 	"AND paramId = 280;", $aData, $iRows, $iColumns)
	_SQLite_Close()
	_SQLite_Shutdown()
	If $aValue[0][0] > 0 Then ;��������� � ����������� ������� ��� s
		ConsoleWrite('������ � ����� ���������. ��������� �����������.' & @CRLF)
		Local $timer = TimerInit()
		;_ArrayDisplay($aValue)
		;������� �������� ������ 0 � ������ 50 ��
		For $j = 1 To $aValue[0][1] * 2 - 1 Step 2
			$sum = 0
			$n = 0
			For $i = 1 To $aValue[0][$j - 1]
				If $aValue[$i][$j] < 0 Or $aValue[$i][$j] > 50 Then
					$aValue[$i][$j] = ''
				EndIf
				If $aValue[$i][$j] <> '' Then
					$sum += $aValue[$i][$j]
					$n += 1
				EndIf
			Next
			$average = $sum / $n
			$sumsquares = 0
			ConsoleWrite('����� ' & $sum & ' ���-�� ��������� ' & $n & ' ������� ' & $average & @CRLF)
			For $i = 1 To $aValue[0][$j - 1]
				If $aValue[$i][$j] <> '' Then
					$sumsquares += ($aValue[$i][$j] - $average) ^ 2
				EndIf
			Next
			$s = Sqrt(1 / ($n + 1) * $sumsquares)
			ConsoleWrite('����� ��������� ' & $sumsquares & ' ����������� ���������� ' & $s & @CRLF)
			; ������� ��� ����. ���������� $sigma = 3. ��� ������� ��������� ��������� �������� ����� ���� ���������.
			$sigma = 4 ; �� ��������� 3
			For $i = 1 To $aValue[0][$j - 1]
				If $aValue[$i][$j] < ($average - $sigma * $s) Or $aValue[$i][$j] > ($average + $sigma * $s) Then
					$aValue[$i][$j] = ''
				EndIf
			Next
		Next
		ConsoleWrite('���������� ���������� ������ ' & Round(TimerDiff($timer)) & ' ����������.' & @CRLF)
		;_ArrayDisplay($aValue)
		;_ArrayDisplay($aLinkName)
		ConsoleWrite('������ ���������� ��������.' & @CRLF)
		GUICtrlSetData($waitLabel, '����������, ���������... ���������� ��������')
		Local $timer = TimerInit()
		_DrawLine($aValue)
		ConsoleWrite('������� ��������� ������ ' & Round(TimerDiff($timer)) & ' ����������.' & @CRLF) ; Round(TimerDiff($timer)/1000/60,2)
		GUICtrlSetData($waitLabel, ' ')
	Else
		GUICtrlSetData($waitLabel, '������ �� ��������� ���������� ������� �� �������.')
	EndIf
EndFunc   ;==>_DrawGraph

Func _DrawLine($aData)
	ConsoleWrite(_Now() & ': ������������ ������� ���������� ��������.' & @CRLF)
	Local $i, $j
	Dim $x[1]
	Dim $y[1]
	Dim $time[1]
	Dim $limits[1][8]
	Local $k = 0
	Local $k_limit = 0
	Local $xmin = 9000000000000
	Local $xmax = 0
	Local $ymin = 1000
	Local $ymax = 0
	ConsoleWrite(_Now() & ': ���������� �������� � ���������.' & @CRLF)
	For $j = 0 To $aData[0][1] - 1
		ConsoleWrite(_Now() & ': ������ ' & $j + 1 & ' �� ' & $aData[0][1] & '.' & @CRLF)
		For $i = 1 To $aData[0][$j * 2]
			;������� �������� ������ ��������
			If $aData[$i][$j * 2 + 1] <> '' Then
				;_ArrayAdd($x,$aData[$i][$j * 2])
				;_ArrayAdd($y,$aData[$i][$j * 2 + 1])
				If $aData[$i][$j * 2] < $xmin Then
					$xmin = $aData[$i][$j * 2]
				EndIf
				If $aData[$i][$j * 2] > $xmax Then
					$xmax = $aData[$i][$j * 2]
				EndIf
				If $aData[$i][$j * 2 + 1] < $ymin Then
					ConsoleWrite('���������� ' & $aData[$i][$j * 2 + 1] & ' ������, ��� ' & $ymin & '. ����������� ' & $aData[$i][$j * 2 + 1] & @CRLF)
					$ymin = $aData[$i][$j * 2 + 1]
				EndIf
				If $aData[$i][$j * 2 + 1] > $ymax Then
					ConsoleWrite('���������� ' & $aData[$i][$j * 2 + 1] & ' ������, ��� ' & $ymax & '. ������������ ' & $aData[$i][$j * 2 + 1] & @CRLF)
					$ymax = $aData[$i][$j * 2 + 1]
				EndIf
			EndIf
		Next
	Next
	ConsoleWrite(_Now() & ': ����������� �������� ���������.' & @CRLF)
	$x[0] = UBound($x) - 1
	;_ArrayDisplay($aData)
	$limits[0][0] = $k_limit
	ConsoleWrite(_Now() & ': ����������� ����� ' & $xmin & @CRLF)
	;Local $xmin = _ArrayMin($x,1,1)
	ConsoleWrite(_Now() & ': ������������ ����� ' & $xmax & @CRLF)
	;Local $xmax = _ArrayMax($x,1,1)
	ConsoleWrite(_Now() & ': ����������� ��������� ' & $ymin & @CRLF)
	;Local $ymin = _ArrayMin($y,1,1)
	ConsoleWrite(_Now() & ': ������������ ��������� ' & $ymax & @CRLF)
	;Local $ymax = _ArrayMax($y,1,1)
	;ConsoleWrite(_Now() & ': ������� ����������!' & @CRLF)
	;ConsoleWrite($xmin & ' ' & $xmax & ' ' & $ymin & ' ' & $ymax)
	;$ymax = 23.2 ;��������� ����������� ����������
	GUICtrlSetData($waitLabel, '')
	; ===== ���� � ������ =====
	Local $hImage ;���� � ������
	$hImage = _GUIImageList_Create() ; ���� � ������
	For $j = 0 To $aData[0][1] - 1
		_GUIImageList_Add($hImage, _GUICtrlListView_CreateSolidBitMap($ListView, _color($j), 16, 16))
	Next
	Local $hPrevImageList = _GUICtrlListView_SetImageList($ListView, $hImage, 1)
	; ===== ������ � ��� ���� =====
	If $enableLogFile Then
		Local $hFileOpen = FileOpen('optic_log.csv', $FO_APPEND)
	EndIf
	; ===== ������ =====
	ConsoleWrite(_Now() & ': ����������� ������.' & @CRLF)
	For $j = 0 To $aData[0][1] - 1
		$min = _ArrayMinMy($aData, 1, 1, $aData[0][$j * 2], $j * 2 + 1)
		$max = _ArrayMax($aData, 1, 1, $aData[0][$j * 2], $j * 2 + 1)
		$average = _MyArrayAverage($aData, $j * 2)
		;GUICtrlCreateListViewItem($aLinkName[$j + 1][0] & '|' & $min & '|' & $max & '|' & Round($max - $min,2) & '|' & $average & '|' & $aLinkName[$j + 1][1],$ListView)
		_GUICtrlListView_AddItem($ListView, $aLinkName[$j + 1][0], $j)
		_GUICtrlListView_AddSubItem($ListView, $j, $min, 1)
		_GUICtrlListView_AddSubItem($ListView, $j, $max, 2)
		_GUICtrlListView_AddSubItem($ListView, $j, Round($max - $min, 2), 3)
		_GUICtrlListView_AddSubItem($ListView, $j, $average, 4)
		_GUICtrlListView_AddSubItem($ListView, $j, $aLinkName[$j + 1][1], 5)
		If $enableLogFile Then
			FileWriteLine($hFileOpen, $aLinkName[$j + 1][0] & ';' & $min & ';' & $max & ';' & Round($max - $min, 2) & ';' & $average & ';' & $aLinkName[$j + 1][1])
		EndIf
	Next
	If $enableLogFile Then
		FileClose($hFileOpen)
	EndIf
	ConsoleWrite(_Now() & ': ������ ������� ����������.' & @CRLF)
	;----- Create Graph area -----
	Global $Graph = _GraphGDIPlus_Create($GUI, 100, 150, 800, 450, 0xFFC0C0C0, 0xFFFFFFFF)
	_GraphGDIPlus_Set_RangeX_IESV($Graph, $xmin, $xmax, 10, 1, 0)

	Local $nTicks, $add
	If ($ymax - $ymin) <= 1 Then
		$add = 0.1
		$nTicks = ($ymax - $ymin + 2 * $add) * 10
		_GraphGDIPlus_Set_RangeY($Graph, $ymin - $add, $ymax + $add, $nTicks, 1, 1)
	ElseIf ($ymax - $ymin) <= 10 Then
		$add = 1
		$nTicks = $ymax - $ymin + 2 * $add
		_GraphGDIPlus_Set_RangeY($Graph, $ymin - $add, $ymax + $add, $nTicks, 1, 1)
	ElseIf ($ymax - $ymin) <= 50 Then
		$add = 1
		$nTicks = $ymax - $ymin + 2 * $add
		_GraphGDIPlus_Set_RangeY($Graph, $ymin - $add, $ymax + $add, $nTicks, 1, 0)
	ElseIf ($ymax - $ymin) > 50 Then
		$add = ($ymax - $ymin) / 8
		$nTicks = 10
		_GraphGDIPlus_Set_RangeY($Graph, $ymin - $add, $ymax + $add, $nTicks, 1, 0)
	Else
		$add = 1
		$nTicks = 10
		_GraphGDIPlus_Set_RangeY($Graph, $ymin - $add, $ymax + $add, $nTicks, 1, 2)
	EndIf
	;_GraphGDIPlus_Set_RangeY($Graph,$ymin - ($ymax - $ymin)/10,$ymax + ($ymax - $ymin)/10,8,1,2)
	;_GraphGDIPlus_Set_GridX($Graph,1,0xFF6993BE)
	_GraphGDIPlus_Set_GridY($Graph, $add, 0xFFf0f0f0, 0xFFc0c0c0)
	;----- Draw the graph -----
	;----- Set line color and size -----
	_GraphGDIPlus_Set_PenSize($Graph, 1)
	;----- Draw lines -----
	;MsgBox(0,'',$x[0])
	ConsoleWrite(_Now() & ': ������ � ������� ����.' & @CRLF)
	For $j = 0 To $aData[0][1] - 1
		_GraphGDIPlus_Set_PenColor($Graph, _color($j))
		Local $step = 1
		If $aData[0][$j * 2] > 400 Then
			$step = Round($aData[0][$j * 2] / 800) * 2
		EndIf
		;MsgBox(0,$x[0],$step)
		$First = True
		ConsoleWrite(_Now() & ': ������ ������ ' & $j + 1 & ' �� ' & $aData[0][1] & '.' & @CRLF)
		For $i = 1 To $aData[0][$j * 2] Step $step
			; ���������� ������������ ��������
			If $aData[$i][$j * 2 + 1] = '' Then
				$First = True
				ContinueLoop
			EndIf

			If $First = True Then _GraphGDIPlus_Plot_Start($Graph, $aData[$i][$j * 2], $aData[$i][$j * 2 + 1])
			$First = False
			_GraphGDIPlus_Plot_Line($Graph, $aData[$i][$j * 2], $aData[$i][$j * 2 + 1])
		Next
	Next
	ConsoleWrite(_Now() & ': ��������� ������� ����������.' & @CRLF)
	_GraphGDIPlus_Refresh($Graph)
	ConsoleWrite(_Now() & ': ������� ���������.' & @CRLF)
EndFunc   ;==>_DrawLine

Func _EPOCH($date)
	Local $d = StringSplit($date, '/ ')
	If $d[0] <> 4 Then
		ConsoleWrite('Error _EPOCH(): ' & $date & @CRLF)
		Exit
	EndIf
	$date = $d[3] & '/' & $d[2] & '/' & $d[1] & ' ' & $d[4]
	Return _DateDiff('s', '1970/01/01 00:00:00', $date) - 3600 * $GMT
EndFunc   ;==>_EPOCH

Func _Exit()
	;----- close down GDI+ and clear graphic -----
	_GraphGDIPlus_Delete($GUI, $Graph)
	GUIDelete()
	Exit
EndFunc   ;==>_Exit

Func _ListSort()
	If GUICtrlRead($label_sort) = "�� ��������" Then
		GUICtrlSetData($label_sort, "�� �������")
	ElseIf GUICtrlRead($label_sort) = "�� �������" Then
		GUICtrlSetData($label_sort, "�� ��������")
	Else
		MsgBox(0, "������", "������ � ������")
	EndIf
	GUICtrlSetData($topo_list, _DataLinkList())
EndFunc   ;==>_ListSort

Func _DataLinkList() ; List of Links
	Local $aResult, $iRows, $iColumns, $iRval
	_SQLite_Startup('sqlite3.dll', False, 1)
	If @error Then
		MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll Can't be Loaded!")
		Exit -1
	EndIf
	_SQLite_Open($db_file)
	$iRval = _SQLite_GetTable2d(-1, "SELECT * FROM topo;", $aResult, $iRows, $iColumns)
	If $iRval = $SQLITE_OK Then
		;_SQLite_Display2DResult($aResult)
		;_ArrayDisplay($aResult)
	Else
		MsgBox($MB_SYSTEMMODAL, "SQLite Error: " & $iRval, _SQLite_ErrMsg())
	EndIf
	Local $l = ''
	Dim $aTopology[1][2]
	$aTopology[0][0] = 0
	Local $aRow1, $aRow2
	For $i = 1 To $iRows
		_SQLite_QuerySingleRow(-1, 'SELECT ne FROM ne WHERE id = ' & $aResult[$i][1] & ';', $aRow1)
		_SQLite_QuerySingleRow(-1, 'SELECT ne FROM ne WHERE id = ' & $aResult[$i][2] & ';', $aRow2)
		_ArrayAdd($aTopology, $aRow1[0] & '|' & $aRow2[0], '|')
		$aTopology[0][0] += 1
	Next
	;_ArrayDisplay($aTopology)
	For $i = 1 To $aTopology[0][0]
		$l &= '|' & $i & ". " & $aTopology[$i][0] & ' - ' & $aTopology[$i][1]
	Next
	If GUICtrlRead($label_sort) = "�� ��������" Then
		For $i = 1 To $aTopology[0][0]
			_ArrayAdd($aTopology, $aTopology[$i][1] & '|' & $aTopology[$i][0], '|')
			$aTopology[0][0] += 1
		Next
		_ArraySort($aTopology)
		;_ArrayDisplay($aTopology)
		$l = ''
		For $i = 1 To $aTopology[0][0]
			$l &= '|' & $aTopology[$i][0] & ' - ' & $aTopology[$i][1]
		Next
	EndIf
	_SQLite_Close()
	_SQLite_Shutdown()
	Return $l
EndFunc   ;==>_DataLinkList

; #FUNCTION# ============================================================================
; Name...........: _GraphGDIPlus_Set_RangeX
; Description ...: Allows user to set the range of the X axis and set ticks and rounding levels
; Syntax.........: _GraphGDIPlus_Set_RangeX(ByRef $aGraphArray,$iLow,$iHigh,$iXTicks = 1,$bLabels = 1,$iRound = 0)
; Parameters ....:   $aGraphArray - the array returned from _GraphGDIPlus_Create
;                    $iLow - the lowest value for the X axis (can be negative)
;                    $iHigh - the highest value for the X axis
;                    $iXTicks - [optional] number of ticks to show below axis, if = 0 then no ticks created
;                    $bLabels - [optional] 1=show labels, any other number=do not show labels
;                    $iRound - [optional] rounding level of label values
; =======================================================================================
Func _GraphGDIPlus_Set_RangeX_IESV(ByRef $aGraphArray, $iLow, $iHigh, $iXTicks = 1, $bLabels = 1, $iRound = 0)
	If IsArray($aGraphArray) = 0 Then Return
	Local $ahTicksX, $ahTicksLabelsX, $i
	;----- load user vars to array -----
	$aGraphArray[6] = $iLow
	$aGraphArray[7] = $iHigh
	;----- prepare nested array -----
	$ahTicksX = $aGraphArray[10]
	$ahTicksLabelsX = $aGraphArray[11]
	;----- delete any existing ticks -----
	For $i = 1 To (UBound($ahTicksX) - 1)
		GUICtrlDelete($ahTicksX[$i])
	Next
	Dim $ahTicksX[1]
	;----- create new ticks -----
	For $i = 1 To $iXTicks + 1
		ReDim $ahTicksX[$i + 1]
		$ahTicksX[$i] = GUICtrlCreateLabel("", (($i - 1) * ($aGraphArray[4] / $iXTicks)) + $aGraphArray[2], _
				$aGraphArray[3] + $aGraphArray[5], 1, 5)
		GUICtrlSetBkColor(-1, 0x000000)
		GUICtrlSetState(-1, 128)
	Next
	;----- delete any existing labels -----
	For $i = 1 To (UBound($ahTicksLabelsX) - 1)
		GUICtrlDelete($ahTicksLabelsX[$i])
	Next
	Dim $ahTicksLabelsX[1]
	;----- create new labels -----
	For $i = 1 To $iXTicks + 1
		ReDim $ahTicksLabelsX[$i + 1]
		$ahTicksLabelsX[$i] = GUICtrlCreateLabel("", _
				($aGraphArray[2] + (($aGraphArray[4] / $iXTicks) * ($i - 1))) - (($aGraphArray[4] / $iXTicks) / 2), _
				$aGraphArray[3] + $aGraphArray[5] + 10, $aGraphArray[4] / $iXTicks, 26, 1)
		GUICtrlSetBkColor(-1, -2)
	Next
	;----- if labels are required, then fill -----
	If $bLabels = 1 Then
		For $i = 1 To (UBound($ahTicksLabelsX) - 1)
			GUICtrlSetData($ahTicksLabelsX[$i], _TimeX($i, $iXTicks, $aGraphArray))
			;_DateAdd('s',Round(_GraphGDIPlus_Reference_Pixel("p", (($i - 1) * ($aGraphArray[4] / $iXTicks)),$aGraphArray[6], $aGraphArray[7], $aGraphArray[4]),0),"1970/01/01 00:00:00"))
			;StringFormat("%." & $iRound & "f", _GraphGDIPlus_Reference_Pixel("p", (($i - 1) * ($aGraphArray[4] / $iXTicks)), _
			;$aGraphArray[6], $aGraphArray[7], $aGraphArray[4])))
		Next
	EndIf
	;----- load created arrays back into array -----
	$aGraphArray[10] = $ahTicksX
	$aGraphArray[11] = $ahTicksLabelsX
EndFunc   ;==>_GraphGDIPlus_Set_RangeX_IESV


Func _TimeX($i, $iXTicks, $aGraphArray)
	Local $timeDate = _DateAdd('s', Round(_GraphGDIPlus_Reference_Pixel("p", (($i - 1) * ($aGraphArray[4] / $iXTicks)), $aGraphArray[6], $aGraphArray[7], $aGraphArray[4]), 0) + $GMT * 3600, "1970/01/01 00:00:00")
	Local $aMyDate, $aMyTime
	_DateTimeSplit($timeDate, $aMyDate, $aMyTime)
	Local $stringTime = ''
	If $aMyDate[0] = 3 Then
		If $aMyDate[2] < 10 Then
			$aMyDate[2] = '0' & $aMyDate[2]
		EndIf
		If $aMyDate[3] < 10 Then
			$aMyDate[3] = '0' & $aMyDate[3]
		EndIf
		$stringTime = $aMyDate[1] & '.' & $aMyDate[2] & '.' & $aMyDate[3] & @CRLF
	EndIf
	If $aMyTime[0] = 3 Then
		If $aMyTime[1] < 10 Then
			$aMyTime[1] = '0' & $aMyTime[1]
		EndIf
		If $aMyTime[2] < 10 Then
			$aMyTime[2] = '0' & $aMyTime[2]
		EndIf
		If $aMyTime[3] < 10 Then
			$aMyTime[3] = '0' & $aMyTime[3]
		EndIf
		$stringTime = $stringTime & $aMyTime[1] & ':' & $aMyTime[2] & ':' & $aMyTime[3]
	EndIf
	Return $stringTime
EndFunc   ;==>_TimeX


Func _MyArrayAverage($array, $n)
	;_ArrayDisplay($array)
	Local $k = 0
	Local $i
	Local $c = 0
	For $i = 1 To $array[0][$n]
		If $array[$i][$n + 1] <> '' Then
			$k += $array[$i][$n + 1]
		Else
			$c += 1
		EndIf
	Next
	Return Round($k / ($array[0][$n]), 2)
EndFunc   ;==>_MyArrayAverage

Func _MyArrayAverage1($array, $n)
	Local $k = 0
	Local $c = 0
	For $i = 1 To $n
		If $array[$i] <> '' Then
			$k += $array[$i]
		Else
			$c += 1
		EndIf
	Next
	Return Round($k / ($n - $c), 2)
EndFunc   ;==>_MyArrayAverage1

Func _color($i) ;������� ���� �� 0 �� 29 � �����
	Dim $color[30]
	$color[0] = 0xFF365A86
	$color[1] = 0xFF883734
	$color[2] = 0xFF6D853D
	$color[3] = 0xFF5A4572
	$color[4] = 0xFF337A8D
	$color[5] = 0xFFB16A2F
	$color[6] = 0xFF40699C
	$color[7] = 0xFF9E413E
	$color[8] = 0xFF7F9A48
	$color[9] = 0xFF695185
	$color[10] = 0xFF3C8DA3
	$color[11] = 0xFFCC7B38
	$color[12] = 0xFF4876AD
	$color[13] = 0xFFB04946
	$color[14] = 0xFF8EAB51
	$color[15] = 0xFF755B94
	$color[16] = 0xFF449DB5
	$color[17] = 0xFFE2893F
	$color[18] = 0xFF4F81BD
	$color[19] = 0xFFC0504D
	$color[20] = 0xFF9BBB59
	$color[21] = 0xFF8064A2
	$color[22] = 0xFF4BACC6
	$color[23] = 0xFFF79646
	$color[24] = 0xFF85A0CA
	$color[25] = 0xFFCD8684
	$color[26] = 0xFFB1C98A
	$color[27] = 0xFFA08FB6
	$color[28] = 0xFF83BED1
	$color[29] = 0xFFF8AE81
	If $i > 29 Then
		$i = $i - 30 * Floor($i / 30)
	EndIf
	Return $color[$i]
EndFunc   ;==>_color

; #FUNCTION# ====================================================================================================================
; Author ........: Stan Syrosenko <stan at syrosenko dot ru>
; ===============================================================================================================================
Func _ArrayMinMy(Const ByRef $aArray, $Numeric = 1, $iStart = -1, $iEnd = -1, $iSubItem = 0)
	Local $iResult = $aArray[$iStart][$iSubItem]
	Local $i
	For $i = $iStart + 1 To $iEnd
		If $aArray[$i][$iSubItem] <> '' Then
			If $aArray[$i][$iSubItem] < $iResult Then
				$iResult = $aArray[$i][$iSubItem]
			EndIf
		EndIf
	Next
	Return $iResult
EndFunc   ;==>_ArrayMinMy
