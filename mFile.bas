Attribute VB_Name = "mFile"
Option Explicit
Option Compare Text
Option Private Module
' --------------------------------------------------------------
' Standard  Module mFile
'           Common methods and functions regarding file objects.
'
' Methods:  Exists      Returns TRUE when the file exists
'           Compare     Displays differences of two files by
'                       means of WinMerge
'           Differ      Returns TRUE when two files have a
'                       different content
'           Delete      Deletes a file
'           Extension   Returns the extension of a file's name
'           GetFile     Returns a file object for a given name
'           ToArray     Returns a file's content in an array
'
' Uses:     No other components
'           (mTrc, fMsg, mMsg and mErH are used by module mTest only).
'
' Requires: Reference to "Microsoft Scripting Runtine"
'
' W. Rauschenberger, Berlin Nov 2020
' -----------------------------------------------------------------------------------
Public Const VALUE_COMMENT = " ; "
Private Const VALUE_VARTYPE = "VarType="

Private Declare PtrSafe Function WritePrivateProfileString _
                Lib "kernel32" Alias "WritePrivateProfileStringA" _
               (ByVal lpw_ApplicationName As String, _
                ByVal lpw_KeyName As String, _
                ByVal lpw_String As String, _
                ByVal lpw_FileName As String) As Long
                
Private Declare PtrSafe Function GetPrivateProfileString _
                Lib "kernel32" Alias "GetPrivateProfileStringA" _
               (ByVal lpg_ApplicationName As String, _
                ByVal lpg_KeyName As String, _
                ByVal lpg_Default As String, _
                ByVal lpg_ReturnedString As String, _
                ByVal nSize As Long, _
                ByVal lpg_FileName As String) As Long

Private Declare PtrSafe Function DeletePrivateProfileSection _
                Lib "kernel32" Alias "WritePrivateProfileStringA" _
               (ByVal section As String, _
                ByVal NoKey As Long, _
                ByVal NoSetting As Long, _
                ByVal name As String) As Long

Private Declare PtrSafe Function DeletePrivateProfileKey _
                Lib "kernel32" Alias "WritePrivateProfileStringA" _
               (ByVal section As String, _
                ByVal Key As String, _
                ByVal Setting As Long, _
                ByVal name As String) As Long
                 
Private Declare PtrSafe Function GetPrivateProfileSectionNames _
                Lib "kernel32.dll" Alias "GetPrivateProfileSectionNamesA" _
               (ByVal lpszReturnBuffer As String, _
                ByVal nSize As Long, _
                ByVal lpName As String) As Long
                 
'Private Declare PtrSafe Function GetPrivateProfileSection _
'                Lib "kernel32" Alias "GetPrivateProfileSectionA" _
'               (ByVal Section As String, _
'                ByVal Buffer As String, _
'                ByVal Size As Long, _
'                ByVal name As String) As Long

Public Enum enVarType
    vbEmpty = 0       ' Empty (nicht initialisiert)
    vbNull = 1        ' Null (keine g�ltigen Daten)
    vbInteger = 2     ' Integer
    vbLong = 3        ' Ganzzahl (Long)
    vbSingle = 4      ' Gleitkommazahl mit einfacher Genauigkeit
    vbDouble = 5      ' Gleitkommazahl mit doppelter Genauigkeit
    vbCurrency = 6    ' W�hrungswert
    vbDate = 7        ' Datumswert
    vbString = 8      ' String
    vbObject = 9      ' Objekt
    vbError = 10      ' Fehlerwert
    vbBoolean = 11    ' Boolescher Wert
End Enum

Public Property Get Arry( _
           Optional ByVal fa_file_full_name As String, _
           Optional ByVal fa_exclude_empty_records As Boolean = False) As Variant
' ------------------------------------------------------------------------------------
' Returns the content of the file (vFile) - which may be provided as file object or
' full file name - as array by considering any kind of line break characters.
' ------------------------------------------------------------------------------------
    Const PROC  As String = "Arry"
    
    On Error GoTo eh
    Dim ts      As TextStream
    Dim a       As Variant
    Dim a1()    As String
    Dim sSplit  As String
    Dim fso     As File
    Dim sFile   As String
    Dim i       As Long
    Dim j       As Long
    
    If Not Exists(fa_file_full_name, fso) _
    Then Err.Raise AppErr(1), ErrSrc(PROC), "The file object (vFile) does not exist!"
    
    '~~ Unload file into a test stream
    With New FileSystemObject
        Set ts = .OpenTextFile(fso.Path, 1)
        With ts
            On Error Resume Next ' may be empty
            sFile = .ReadAll
            .Close
        End With
    End With
    
    If sFile = vbNullString Then GoTo xt
    
    '~~ Get the kind of line break used
    If InStr(sFile, vbCr) <> 0 Then sSplit = vbCr
    If InStr(sFile, vbLf) <> 0 Then sSplit = sSplit & vbLf
    
    '~~ Test stream to array
    a = Split(sFile, sSplit)
    
    '~~ Remove any leading or trailing empty items
    mBasic.ArrayTrimm a
    
    If Not fa_exclude_empty_records Then
        Arry = a
    Else
        '~~ Count empty records
        j = 0
        For i = LBound(a) To UBound(a)
            If Len(Trim$(a(i))) = 0 Then j = j + 1
        Next i
        j = UBound(a) - j
        ReDim a1(j - 1)
        j = 0
        For i = LBound(a) To UBound(a)
            If Len(Trim$(a(i))) > 0 Then
                a1(j) = a(i)
                j = j + 1
            End If
        Next i
        Arry = a1
    End If
    
xt: Exit Property
    
eh: ErrMsg ErrSrc(PROC)
End Property

Public Property Get SectionNames(Optional ByVal sn_file As String) As Dictionary
' ------------------------------------------------------------------------------
' Returns a Dictionary of all section names [.....] in a file.
' ------------------------------------------------------------------------------
    Const PROC = "SectionNames"
    
    On Error GoTo eh
    Dim asSections()     As String
    Dim dct             As Dictionary
    Dim i               As Long
    Dim iLen            As Long
    Dim strBuffer       As String
    Dim sSectionName    As String
    
    Set dct = New Dictionary
    Set SectionNames = New Dictionary
    
    Do While (iLen = Len(strBuffer) - 2) Or (iLen = 0)
        If strBuffer = vbNullString _
        Then strBuffer = Space$(256) _
        Else strBuffer = String(Len(strBuffer) * 2, 0)
        iLen = GetPrivateProfileSectionNames(strBuffer, Len(strBuffer), sn_file)
    Loop
    strBuffer = Left$(strBuffer, iLen)
    
    If Len(strBuffer) <> 0 Then
        i = 0
        asSections = Split(strBuffer, vbNullChar)
        For i = LBound(asSections) To UBound(asSections)
            sSectionName = asSections(i)
            If Len(sSectionName) <> 0 Then
                If Not dct.Exists(sSectionName) _
                Then mDct.DctAdd add_dct:=dct, add_key:=sSectionName, add_item:=sSectionName, add_seq:=seq_ascending
            End If
        Next i
    End If
    
    Set SectionNames = dct

xt: Exit Property
    
eh: ErrMsg ErrSrc(PROC)
End Property

Public Property Get Txt( _
         Optional ByVal tx_file_full_name As String, _
         Optional ByVal tx_append As Boolean = True, _
         Optional ByRef tx_split As String) As String
' ----------------------------------------------------------
' Returns the content of the text file (tx_file_full_name)
' as string plus the line split character/string (tx_split).
' ----------------------------------------------------------
    Const PROC = "TxtGet"
    
    On Error GoTo eh
    Dim fso As New FileSystemObject
    Dim ts  As TextStream
    
    tx_append = tx_append ' not used! just for the coincidence with tLet
    If Not fso.FileExists(tx_file_full_name) _
    Then Err.Raise AppErr(1), ErrSrc(PROC), "The file '" & tx_file_full_name & "' does not exist!"

    Set ts = fso.OpenTextFile(FileName:=tx_file_full_name, IOMode:=ForReading)
    Txt = ts.ReadAll
    If InStr(Txt, vbCrLf) <> 0 Then
        tx_split = vbCrLf
    ElseIf InStr(Txt, vbCr) <> 0 Then
        tx_split = vbCr
    ElseIf InStr(Txt, vbLf) <> 0 Then
        tx_split = vbLf
    End If
xt: Exit Property

eh: ErrMsg ErrSrc(PROC)
End Property

Public Property Let Txt( _
         Optional ByVal tx_file_full_name As String, _
         Optional ByVal tx_append As Boolean = True, _
         Optional ByRef tx_split As String, _
                  ByVal tx_string As String)
' -------------------------------------------------------
' Write the test string (tx_string) to the file
' (tx_file_full_name) optionally appended.
' -------------------------------------------------------
    Const PROC = "TxtLet"
    
    On Error GoTo eh
    Dim fso As New FileSystemObject
    Dim ts  As TextStream
    
    tx_split = tx_split ' not used! just for coincidence with Get
    With fso
        If tx_append Then
            If Not .FileExists(tx_file_full_name) Then .CreateTextFile tx_file_full_name
            Set ts = .OpenTextFile(tx_file_full_name, IOMode:=ForAppending)
        Else
            If .FileExists(tx_file_full_name) Then .DeleteFile (tx_file_full_name)
            .CreateTextFile tx_file_full_name
            Set ts = .OpenTextFile(FileName:=tx_file_full_name _
                                 , IOMode:=ForWriting _
                                  )
        End If
    End With
    ts.WriteLine tx_string

xt: ts.Close
    Set fso = Nothing
    Set ts = Nothing
    Exit Property
    
eh: ErrMsg ErrSrc(PROC)
End Property

Public Property Get value( _
           Optional ByVal vl_file As String, _
           Optional ByVal vl_section As String, _
           Optional ByVal vl_value_name As String, _
           Optional ByRef vl_comment As String) As Variant
' -----------------------------------------------------------
' Read a value with a specific name from a section
' [section]
' <value-name>=<value>
' -----------------------------------------------------------
    Const PROC  As String = "ValueGet"
    
    On Error GoTo eh
    Dim lResult As Long
    Dim sRetVal As String
    Dim vValue  As Variant

    sRetVal = String(32767, 0)
    lResult = GetPrivateProfileString( _
                                      lpg_ApplicationName:=vl_section _
                                    , lpg_KeyName:=vl_value_name _
                                    , lpg_Default:="" _
                                    , lpg_ReturnedString:=sRetVal _
                                    , nSize:=Len(sRetVal) _
                                    , lpg_FileName:=vl_file _
                                     )
    vValue = Left$(sRetVal, lResult)
    
    '~~ Unstrip and return a possibly added comment provided it's not a VarType= comment
    '~~ which indicates which kind of vartype is to be returned
    If InStr(vValue, VALUE_COMMENT) <> 0 Then
        vl_comment = Split(vValue, VALUE_COMMENT)(1)
        If InStr(vl_comment, VALUE_VARTYPE) <> 0 Then
            '~~ The comment is a VarType indication generated by the optional vartype argument
            Select Case Split(vl_comment, "=")(1)
                Case enVarType.vbBoolean:   value = CBool(Split(vValue, VALUE_COMMENT)(0))
                Case enVarType.vbCurrency:  value = CCur(Split(vValue, VALUE_COMMENT)(0))
                Case enVarType.vbDate:      value = CDate(Split(vValue, VALUE_COMMENT)(0))
                Case enVarType.vbDouble:    value = CDbl(Split(vValue, VALUE_COMMENT)(0))
                Case enVarType.vbInteger:   value = CInt(Split(vValue, VALUE_COMMENT)(0))
                Case enVarType.vbLong:      value = CLng(Split(vValue, VALUE_COMMENT)(0))
                Case enVarType.vbSingle:    value = CSng(Split(vValue, VALUE_COMMENT)(0))
                Case Else:                  value = Split(vValue, VALUE_COMMENT)(0)
            End Select
            vl_comment = vbNullString
        End If
    Else
        value = vValue
    End If
    
xt: Exit Property

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOpt1ResumeError: Stop: Resume
        Case mErH.DebugOpt2ResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Property

Public Property Let value( _
           Optional ByVal vl_file As String, _
           Optional ByVal vl_section As String, _
           Optional ByVal vl_value_name As String, _
           Optional ByRef vl_comment As String, _
                    ByVal vl_value As Variant)
' --------------------------------------------------
' Write a value under a name into a section in a
' file in the form: [section]
'                   <value-name>=<value>
' --------------------------------------------------
    Const PROC = "ValueLet"
        
    On Error GoTo eh
    Dim lChars      As Long
    Dim sValue      As String
    Dim sComment    As String
    
    If vl_comment <> vbNullString Then
        sComment = " ; " & vl_comment
        sComment = Replace(sComment, VALUE_COMMENT & VALUE_COMMENT, VALUE_COMMENT)
        sComment = Replace(sComment, ";;", ";")
    End If
    
    Select Case VarType(vl_value)
        Case vbBoolean: sValue = VBA.CStr(VBA.CLng(vl_value))
        Case Else:      sValue = vl_value
    End Select
    sValue = sValue & sComment
    
    lChars = WritePrivateProfileString(lpw_ApplicationName:=vl_section _
                                     , lpw_KeyName:=vl_value_name _
                                     , lpw_String:=sValue _
                                     , lpw_FileName:=vl_file)
    If lChars = 0 Then
        MsgBox "System error when writing property" & vbLf & _
               "Section    = '" & vl_section & "'" & vbLf & _
               "Value name = '" & vl_value_name & "'" & vbLf & _
               "Value      = '" & CStr(vl_value) & "'" & vbLf & _
               "Value file = '" & vl_file & "'"
    End If

xt: Exit Property

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOpt1ResumeError: Stop: Resume
        Case mErH.DebugOpt2ResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Property

Public Function AppErr(ByVal err_no As Long) As Long
' -----------------------------------------------------------------
' Used with Err.Raise AppErr(<l>).
' When the error number <l> is > 0 it is considered an "Application
' Error Number and vbObjectErrror is added to it into a negative
' number in order not to confuse with a VB runtime error.
' When the error number <l> is negative it is considered an
' Application Error and vbObjectError is added to convert it back
' into its origin positive number.
' ------------------------------------------------------------------
    If err_no < 0 Then
        AppErr = err_no - vbObjectError
    Else
        AppErr = vbObjectError + err_no
    End If
End Function

Private Function AppIsInstalled(ByVal sApp As String) As Boolean
    
    Dim i As Long: i = 1
    
    Do Until Left(Environ$(i), 5) = "Path="
        i = i + 1
    Loop
    AppIsInstalled = InStr(Environ$(i), sApp) <> 0

End Function

Private Function ArrayCompare(ByVal ac_a1 As Variant, _
                              ByVal ac_a2 As Variant, _
                     Optional ByVal ac_stop_after As Long = 10, _
                     Optional ByVal ac_id1 As String = vbNullString, _
                     Optional ByVal ac_id2 As String = vbNullString, _
                     Optional ByVal ac_ignore_case As Boolean = True) As Variant
' ----------------------------------------------------------------------------
' Returns an array of n (as_stop_after) lines which are different between
' array 1 (ac_a1) and array 2 (ac_a2). Each line element contains the
' lines which differ in the form:
' linenumber: <ac_id1> '<line>' || <ac_id2> '<line>'
' The comparisonWhen a value for stop after n (ac_stop_after) lines.
' Note: Either or both arrays may not be assigned (=empty).
' ----------------------------------------------------------------------------
    Const PROC = "ArrayCompare"
    
    On Error GoTo eh
    Dim l           As Long
    Dim i           As Long
    Dim va()        As Variant
    Dim vbCompare   As Long

    If Not mBasic.ArrayIsAllocated(ac_a1) And mBasic.ArrayIsAllocated(ac_a2) Then
        va = ac_a2
    ElseIf mBasic.ArrayIsAllocated(ac_a1) And Not mBasic.ArrayIsAllocated(ac_a2) Then
        va = ac_a1
    ElseIf Not mBasic.ArrayIsAllocated(ac_a1) And Not mBasic.ArrayIsAllocated(ac_a2) Then
        GoTo xt
    End If
    
    If ac_ignore_case Then vbCompare = vbTextCompare Else vbCompare = vbBinaryCompare
    
    l = 0
    For i = LBound(ac_a1) To Min(UBound(ac_a1), UBound(ac_a2))
        If StrComp(ac_a1(i), ac_a2(i), vbCompare) <> 0 Then
            ReDim Preserve va(l)
            va(l) = Format(i, "000") & " " & ac_id1 & " '" & ac_a1(i) & "'  < >  '" & ac_id2 & " " & ac_a2(i) & "'"
            l = l + 1
            If ac_stop_after > 0 And l >= ac_stop_after Then GoTo xt
        End If
    Next i
    
    If UBound(ac_a1) < UBound(ac_a2) Then
        For i = UBound(ac_a1) + 1 To UBound(ac_a2)
            ReDim Preserve va(l)
            va(l) = Format(i, "000") & ac_id2 & ": '" & ac_a2(i) & "'"
            l = l + 1
            If ac_stop_after > 0 And l >= ac_stop_after Then GoTo xt
        Next i
        
    ElseIf UBound(ac_a2) < UBound(ac_a1) Then
        For i = UBound(ac_a2) + 1 To UBound(ac_a1)
            ReDim Preserve va(l)
            va(l) = Format(i, "000") & " " & ac_id1 & " '" & ac_a1(i) & "'"
            l = l + 1
            If ac_stop_after > 0 And l >= ac_stop_after Then GoTo xt
        Next i
    End If

xt: ArrayCompare = va
    Exit Function

eh: ErrMsg ErrSrc(PROC)
End Function

Public Function Compare(ByVal file_left_full_name As String, _
                        ByVal file_left_title As String, _
                        ByVal file_right_full_name As String, _
                        ByVal file_right_title As String) As Long
' ---------------------------------------------------------------------
' Compares two text files by means of WinMerge. An error is raised when
' WinMerge is not installed of one of the two files doesn't exist.
' ----------------------------------------------------------------------
    Const PROC = "Compare"
    
    On Error GoTo eh
    Dim waitOnReturn    As Boolean: waitOnReturn = True
    Dim windowStyle     As Integer: windowStyle = 1
    Dim sCommand        As String
    Dim fso             As New FileSystemObject
    Dim wshShell        As Object
    
    If Not AppIsInstalled("WinMerge") _
    Then Err.Raise Number:=AppErr(1) _
                 , Source:=ErrSrc(PROC) _
                 , Description:="WinMerge is obligatory for the Compare service of this module but not installed!" & vbLf & vbLf & _
                                "(See ""https://winmerge.org/downloads/?lang=en"" for download)"
        
    If Not fso.FileExists(file_left_full_name) _
    Then Err.Raise Number:=AppErr(2) _
                 , Source:=ErrSrc(PROC) _
                 , Description:="The file """ & file_left_full_name & """ does not exist!"
    
    If Not fso.FileExists(file_right_full_name) _
    Then Err.Raise Number:=AppErr(3) _
                 , Source:=ErrSrc(PROC) _
                 , Description:="The file """ & file_right_full_name & """ does not exist!"
    
    sCommand = "WinMergeU /e" & _
               " /dl " & DQUOTE & file_left_title & DQUOTE & _
               " /dr " & DQUOTE & file_right_title & DQUOTE & " " & _
               """" & file_left_full_name & """" & " " & _
               """" & file_right_full_name & """"
    
    Set wshShell = CreateObject("WScript.Shell")
    With wshShell
        Compare = .Run(Command:=sCommand, windowStyle:=windowStyle, waitOnReturn:=waitOnReturn)
    End With
        
xt: Exit Function

eh: Select Case mErH.ErrMsg(ErrSrc(PROC))
        Case mErH.DebugOpt1ResumeError: Stop: Resume
        Case mErH.DebugOpt2ResumeNext: Resume Next
        Case mErH.ErrMsgDefaultButton: End
    End Select
End Function

Public Sub Delete(ByVal v As Variant)

    Dim fl  As File

    With New FileSystemObject
        If TypeName(v) = "File" Then
            Set fl = v
            .DeleteFile fl.Path
        ElseIf TypeName(v) = "String" Then
            If .FileExists(v) Then
                .DeleteFile v
            End If
        End If
    End With
    
End Sub

Private Sub ErrMsg( _
             ByVal err_source As String, _
    Optional ByVal err_no As Long = 0, _
    Optional ByVal err_dscrptn As String = vbNullString)
' ------------------------------------------------------
' This Common Component does not have its own error
' handling. Instead it passes on any error to the
' caller's error handling.
' ------------------------------------------------------
    
    If err_no = 0 Then err_no = Err.Number
    If err_dscrptn = vbNullString Then err_dscrptn = Err.Description

    Err.Raise Number:=err_no, Source:=err_source, Description:=err_dscrptn

End Sub

Private Function ErrSrc(ByVal sProc As String) As String
    ErrSrc = ThisWorkbook.name & ": mFile." & sProc
End Function

Public Function Exists(ByVal xst_file As Variant, _
              Optional ByRef xst_fso As File = Nothing, _
              Optional ByRef xst_cll As Collection = Nothing) As Boolean
' ------------------------------------------------------------------
' Returns TRUE when the file (xst_file) - which may be a file object
' or a file's full name - exists and furthermore:
' - when the file's full name ends with a wildcard * all
'   subfolders are scanned and any file which meets the criteria
'   is returned as File object in a collection (xst_cll),
' - when the files's full name does not end with a wildcard * the
'   existing file is returned as a File object (xst_fso).
' ----------------------------------------------------------------
    Const PROC  As String = "Exists"    ' This procedure's name for the error handling and execution tracking
    
    On Error GoTo eh
    Dim sTest   As String
    Dim sFile   As String
    Dim fldr    As Folder
    Dim sfldr   As Folder   ' Sub-Folder
    Dim fl      As File
    Dim sPath   As String
    Dim queue   As Collection

    Exists = False
    Set xst_cll = New Collection

    If TypeName(xst_file) <> "File" And TypeName(xst_file) <> "String" _
    Then Err.Raise AppErr(1), ErrSrc(PROC), "The File (parameter xst_file) for the File's existence check is neither a full path/file name nor a file object!"
    If Not TypeName(xst_fso) = "Nothing" And Not TypeName(xst_fso) = "File" _
    Then Err.Raise AppErr(2), ErrSrc(PROC), "The provided return parameter (xst_fso) is not a File type!"
    If Not TypeName(xst_cll) = "Nothing" And Not TypeName(xst_cll) = "Collection" _
    Then Err.Raise AppErr(3), ErrSrc(PROC), "The provided return parameter (xst_cll) is not a Collection type!"

    If TypeOf xst_file Is File Then
        With New FileSystemObject
            On Error Resume Next
            sTest = xst_file.name
            Exists = Err.Number = 0
            If Exists Then
                '~~ Return the existing file as File object
                Set xst_fso = .GetFile(xst_file.Path)
                GoTo xt
            End If
        End With
    ElseIf VarType(xst_file) = vbString Then
        With New FileSystemObject
            sFile = Split(xst_file, "\")(UBound(Split(xst_file, "\")))
            If Not Right(sFile, 1) = "*" Then
                Exists = .FileExists(xst_file)
                If Exists Then
                    '~~ Return the existing file as File object
                    Set xst_fso = .GetFile(xst_file)
                    GoTo xt
                End If
            Else
                sPath = Replace(xst_file, "\" & sFile, vbNullString)
                sFile = Replace(sFile, "*", vbNullString)
                '~~ Wildcard file existence check is due
                Set fldr = .GetFolder(sPath)
                Set queue = New Collection
                queue.Add .GetFolder(sPath)

                Do While queue.Count > 0
                    Set fldr = queue(queue.Count)
                    queue.Remove queue.Count ' dequeue the processed subfolder
                    For Each sfldr In fldr.SubFolders
                        queue.Add sfldr ' enqueue (collect) all subfolders
                    Next sfldr
                    For Each fl In fldr.Files
                        If InStr(fl.name, sFile) <> 0 And Left(fl.name, 1) <> "~" Then
                            '~~ Return the existing file which meets the search criteria
                            '~~ as File object in a collection
                            xst_cll.Add fl
                         End If
                    Next fl
                Loop
                If xst_cll.Count > 0 Then Exists = True
            End If
        End With
    End If

xt: Exit Function
    
eh: ErrMsg ErrSrc(PROC)
End Function

Public Function Extension(ByVal vFile As Variant)

    With New FileSystemObject
        If TypeName(vFile) = "File" Then
            Extension = .GetExtensionName(vFile.Path)
        Else
            Extension = .GetExtensionName(vFile)
        End If
    End With

End Function

Private Function Fc(ByVal fc_file1 As String, fc_file2 As String)
    Const PROC = "Fc"
    
    On Error GoTo eh
    Dim waitOnReturn    As Boolean: waitOnReturn = True
    Dim windowStyle     As Integer: windowStyle = 1
    Dim sCommand        As String
    Dim fso             As New FileSystemObject
    Dim wshShell        As Object
    
    If Not fso.FileExists(fc_file1) _
    Then Err.Raise Number:=AppErr(2) _
                 , Source:=ErrSrc(PROC) _
                 , Description:="The file """ & fc_file1 & """ does not exist!"
    
    If Not fso.FileExists(fc_file2) _
    Then Err.Raise Number:=AppErr(3) _
                 , Source:=ErrSrc(PROC) _
                 , Description:="The file """ & fc_file2 & """ does not exist!"
    
    sCommand = "Fc /C /W " & _
               """" & fc_file1 & """" & " " & _
               """" & fc_file2 & """"
    
    Set wshShell = CreateObject("WScript.Shell")
    With wshShell
        Fc = .Run(Command:=sCommand, windowStyle:=windowStyle, waitOnReturn:=waitOnReturn)
    End With
        
xt: Exit Function

eh: ErrMsg ErrSrc(PROC)
End Function

Public Property Get Temp(Optional ByVal tmp_extension As String = ".tmp") As String
    Dim fso As New FileSystemObject
    If Left(tmp_extension, 1) <> "." Then tmp_extension = "." & tmp_extension
    Temp = Replace(fso.GetTempName, ".tmp", tmp_extension)
    Temp = fso.GetParentFolderName(ActiveWorkbook.FullName) & "\" & Temp
    Set fso = Nothing
End Property

Public Function GetFile(ByVal gf_path As String) As File
    With New FileSystemObject
        Set GetFile = .GetFile(gf_path)
    End With
End Function

Public Sub NameRemove(ByVal nr_file As String, _
                      ByVal nr_section As String, _
                      ByVal nr_name As String)
' --------------------------------------------------
'
' --------------------------------------------------
    DeletePrivateProfileKey section:=nr_section, Key:=nr_name, Setting:=0, name:=nr_file
End Sub

Public Function sAreEqual(ByVal fc_file1 As String, fc_file2 As String) As Variant
    Const PROC = "Fc"
    
    On Error GoTo eh
    Dim bWaitOnReturn   As Boolean: bWaitOnReturn = True
    Dim iWindowStyle    As Integer: iWindowStyle = 1
    Dim sFcBat          As String
    Dim fso             As New FileSystemObject
    Dim vResult         As Variant
    Dim sTempResult     As String
    Dim sTempFcBat      As String
    Dim sTempFcVbs      As String
    
    If Not fso.FileExists(fc_file1) _
    Then Err.Raise Number:=AppErr(2) _
                 , Source:=ErrSrc(PROC) _
                 , Description:="The file """ & fc_file1 & """ does not exist!"
    
    If Not fso.FileExists(fc_file2) _
    Then Err.Raise Number:=AppErr(3) _
                 , Source:=ErrSrc(PROC) _
                 , Description:="The file """ & fc_file2 & """ does not exist!"
        
    sTempResult = fso.GetParentFolderName(ThisWorkbook.FullName) & "\" & fso.GetTempName
    fso.CreateTextFile sTempResult
    
    sFcBat = "fc.exe /c /lb500 /w " & _
               """" & fc_file1 & """ " & _
               """" & fc_file2 & """"
    sTempFcBat = Replace(fso.GetTempName, ".tmp", ".bat")
    sTempFcBat = fso.GetParentFolderName(ThisWorkbook.FullName) & "\" & sTempFcBat
    mFile.Txt(tx_file_full_name:=sTempFcBat _
            , tx_append:=False _
             ) = sFcBat
    
    vResult = ShellRun("nircmd exec2 hide " & sTempFcBat & " " & sTempResult)
    
xt: With fso
        On Error Resume Next
        .DeleteFile sTempFcBat
        On Error Resume Next
        .DeleteFile sTempFcVbs
        On Error Resume Next
        .DeleteFile sTempResult
    End With
    Exit Function

eh: ErrMsg ErrSrc(PROC)
End Function

Public Function sDiffer( _
                  ByVal dif_file1 As File, _
                  ByVal dif_file2 As File, _
         Optional ByVal dif_stop_after As Long = 1, _
         Optional ByVal dif_ignore_empty_records As Boolean = False, _
         Optional ByVal dif_ignore_case As Boolean = True, _
         Optional ByRef dif_lines As Variant) As Boolean
' -----------------------------------------------------------------------------
' Returns TRUE when the content of file (dif_file1) differs from the content in
' file (dif_file2). The comparison stops after (dif_stop_after) detected
' differences. The detected different lines are optionally returned (vResult).
' ------------------------------------------------------------------------------
    Const PROC = "sDiffer"
    
    On Error GoTo eh
    Dim a1      As Variant
    Dim a2      As Variant
    Dim vLines  As Variant

    a1 = mFile.ToArray(ta_file:=dif_file1, ta_exclude_empty_records:=dif_ignore_empty_records)
    a2 = mFile.ToArray(ta_file:=dif_file2, ta_exclude_empty_records:=dif_ignore_empty_records)
    vLines = ArrayCompare(ac_a1:=a1, ac_a2:=a2, ac_stop_after:=dif_stop_after, ac_ignore_case:=dif_ignore_case)
    If mBasic.ArrayIsAllocated(arr:=vLines) Then
        sDiffer = True
    End If
    dif_lines = vLines
    
xt: Exit Function

eh: ErrMsg ErrSrc(PROC)
End Function

Public Sub SectionMove()

End Sub

Public Sub SectionReplace()

End Sub

Public Sub SectionsCopy(ByVal sc_section_names As Variant, _
                        ByVal sc_file_from As String, _
                        ByVal sc_file_to As String, _
               Optional ByVal sc_replace As Boolean = False)
' ----------------------------------------------------------
'
' ----------------------------------------------------------
    Const PROC = "SectionCopy"
    
    On Error GoTo eh
    Dim dctSections As Dictionary
    Dim i           As Long
    Dim cll         As New Collection
    
    Select Case VarType(sc_section_names)
        Case Is >= vbArray
            For i = LBound(sc_section_names) To UBound(sc_section_names)
                cll.Add sc_section_names(i)
            Next i
            SectionsCopy sc_file_from:=sc_file_from, sc_file_to:=sc_file_to, sc_section_names:=cll, sc_replace:=sc_replace
            GoTo xt
        Case vbString
            For i = LBound(Split(sc_section_names, ",")) To UBound(Split(sc_section_names, ","))
                cll.Add Split(sc_section_names, ",")(i)
            Next i
            SectionsCopy sc_file_from:=sc_file_from, sc_file_to:=sc_file_to, sc_section_names:=cll, sc_replace:=sc_replace
            GoTo xt
        Case vbObject
            Select Case TypeName(sc_section_names)
                Case "Dictionary"
                    For i = 0 To sc_section_names.Count
                        cll.Add sc_section_names.Items()(i)
                    Next i
                    SectionsCopy sc_file_from:=sc_file_from, sc_file_to:=sc_file_to, sc_section_names:=cll, sc_replace:=sc_replace
                    GoTo xt
                Case "Collection"
                    Set dctSections = SectionsGet(sg_file:=sc_file_from, sg_section_names:=sc_section_names)
                    If sc_replace Then mFile.SectionsRemove sr_file:=sc_file_to, sr_section_names:=sc_section_names
                    SectionsLet sl_sections:=dctSections, sl_file:=sc_file_to
                    GoTo xt
                Case Else: GoTo xt
            End Select
    End Select

xt: Set cll = Nothing
    Exit Sub
    
eh: ErrMsg ErrSrc(PROC)
End Sub

Public Function SectionsGet( _
                      ByVal sg_file As String, _
             Optional ByVal sg_section_names As Variant) As Dictionary
' -----------------------------------------------------------------------
' Returns a Dictionary with complete sections, one for each provided
' section name (sg_section_names). Each section is identified by the key
' and the item is a Dictionary of all values - with the value name as
' the key and the value as the item.
' Recursively called until the sg_section_names argument is a Collection.
' -----------------------------------------------------------------------
    Const PROC = "SectionGet"
    
    On Error GoTo eh
    Dim dctSections As Dictionary
    Dim dctValues   As Dictionary
    Dim i           As Long
    Dim sSection    As String
    Dim cll         As New Collection
    
    If Not IsMissing(sg_section_names) Then
        Select Case VarType(sg_section_names)
            Case Is >= vbArray
                For i = LBound(sg_section_names) To UBound(sg_section_names)
                    cll.Add sg_section_names(i)
                Next i
                Set dctSections = SectionsGet(sg_file:=sg_file, sg_section_names:=cll)
                GoTo xt
            Case vbString
                For i = LBound(Split(sg_section_names, ",")) To UBound(Split(sg_section_names, ","))
                    cll.Add Split(sg_section_names, ",")(i)
                Next i
                Set dctSections = SectionsGet(sg_file:=sg_file, sg_section_names:=cll)
                GoTo xt
            Case vbObject
                Select Case TypeName(sg_section_names)
                    Case "Dictionary"
                        For i = 0 To sg_section_names.Count
                            cll.Add sg_section_names.Items()(i)
                        Next i
                        Set dctSections = SectionsGet(sg_file:=sg_file, sg_section_names:=cll)
                        GoTo xt
                    Case "Collection"
                        Set dctSections = New Dictionary
                        Set cll = sg_section_names
                        For i = 1 To cll.Count
                            sSection = cll(i)
                            Set dctValues = mFile.Values(vl_file:=sg_file _
                                                     , vl_section:=sSection _
                                                      )
                            dctSections.Add Key:=sSection _
                                         , Item:=dctValues
                        Next i
                        GoTo xt
                    Case Else: GoTo xt
                End Select
        End Select
    Else
        '~~ Return all sections
        
    End If
xt: Set cll = Nothing
    If dctSections.Count = 0 _
    Then Err.Raise Number:=AppErr(1) _
                 , Source:=ErrSrc(PROC) _
                 , Description:="The name of the section(s) is provided neither as a comma delimited " & _
                                "string, nor an array of strings, nor a Dictionary, nor a Collection!"
    Set SectionsGet = dctSections
    Exit Function
    
eh: ErrMsg ErrSrc(PROC)
End Function

Public Sub SectionsLet( _
                 ByVal sl_file As String, _
                 ByVal sl_sections As Dictionary)
' -----------------------------------------------------
' Writes for each item in the Dictionary (sl_sections
' provided by the SectionsGet service) a complete
' section into the file (sl_file).
' In other words: Together with the SectionsGet service
' this allows to transfer sections between files
' -----------------------------------------------------
    Const PROC = "SectionLet"
    
    On Error GoTo eh
    Dim vn          As Variant
    Dim vs          As Variant
    Dim dctValues   As Dictionary
    Dim sSection    As String
    Dim vValue      As Variant
    Dim sName       As String
    
    For Each vs In sl_sections
        sSection = vs
        Set dctValues = sl_sections(vs)
        For Each vn In dctValues
            sName = vn
            vValue = dctValues(vn)
            mFile.value(vl_file:=sl_file _
                    , vl_section:=sSection _
                    , vl_value_name:=sName _
                    ) = vValue
        Next vn
    Next vs
    
xt: Exit Sub
    
eh: ErrMsg ErrSrc(PROC)
End Sub

Public Sub SectionsRemove( _
                    ByVal sr_file As String, _
                    ByVal sr_section_names As Variant)
' ----------------------------------------------------
' Removes all sections in sr_section_names from file
' sr_file.
' ----------------------------------------------------
    Const PROC = "SectionsRemove"
    
    On Error GoTo eh
    Dim i               As Long
    Dim cll             As New Collection
    Dim v               As Variant
    Dim sSectionName    As String
    
    Select Case VarType(sr_section_names)
        Case Is >= vbArray
            For i = LBound(sr_section_names) To UBound(sr_section_names)
                cll.Add sr_section_names(i)
            Next i
            SectionsRemove sr_file:=sr_file, sr_section_names:=cll
            GoTo xt
        Case vbString
            For i = LBound(Split(sr_section_names, ",")) To UBound(Split(sr_section_names, ","))
                cll.Add Split(sr_section_names, ",")(i)
            Next i
            SectionsRemove sr_file:=sr_file, sr_section_names:=cll
            GoTo xt
        Case vbObject
            Select Case TypeName(sr_section_names)
                Case "Dictionary"
                    For i = 0 To sr_section_names.Count
                        cll.Add sr_section_names.Items()(i)
                    Next i
                    SectionsRemove sr_file:=sr_file, sr_section_names:=cll
                    GoTo xt
                Case "Collection"
                    For Each v In sr_section_names
                        sSectionName = v
                        DeletePrivateProfileSection section:=sSectionName, NoKey:=0, NoSetting:=0, name:=sr_file
                    Next v
                    GoTo xt
                Case Else: GoTo xt
            End Select
    End Select
    
xt: Set cll = Nothing
    Exit Sub
    
eh: ErrMsg ErrSrc(PROC)
End Sub

Public Function SelectFile( _
            Optional ByVal sel_init_path As String = vbNullString, _
            Optional ByVal sel_filters As String = "*.*", _
            Optional ByVal sel_filter_name As String = "File", _
            Optional ByVal sel_title As String = vbNullString, _
            Optional ByRef sel_result As File) As Boolean
' --------------------------------------------------------------
' When a file had been selected TRUE is returned and the
' selected file is returned as File object (sel_result).
' --------------------------------------------------------------
    Const PROC = "SelectFile"
    
    On Error GoTo eh
    Dim fDialog As FileDialog
    Dim v       As Variant

    Set fDialog = Application.FileDialog(msoFileDialogFilePicker)
    With fDialog
        .AllowMultiSelect = False
        If sel_title = vbNullString _
        Then .Title = "Select a(n) " & sel_filter_name _
        Else .Title = sel_title
        .InitialFileName = sel_init_path
        .Filters.Clear
        For Each v In Split(sel_filters, ",")
            .Filters.Add sel_filter_name, v
         Next v
         
        If .show = -1 Then
            '~~ A fie had been selected
           With New FileSystemObject
            Set sel_result = .GetFile(fDialog.SelectedItems(1))
            SelectFile = True
           End With
        End If
        '~~ When no file had been selected the sel_result will be Nothing
    End With

xt: Exit Function

eh: ErrMsg ErrSrc(PROC)
End Function

Public Function ShellRun(sCmd As String) As String
' ------------------------------------------------------
' Run a shell command, returning the output as a string.
' ------------------------------------------------------
    Dim oShell As Object
    Set oShell = CreateObject("WScript.Shell")

    'run command
    Dim oExec As Object
    Dim oOutput As Object
    Set oExec = oShell.Exec(sCmd)
    Set oOutput = oExec.StdOut

    'handle the results as they are written to and read from the StdOut object
    Dim s As String
    Dim sLine As String
    While Not oOutput.AtEndOfStream
        sLine = oOutput.ReadLine
        If sLine <> "" Then s = s & sLine & vbCrLf
    Wend

    ShellRun = s

End Function

Public Function ToArray(ByVal ta_file As Variant, _
               Optional ByVal ta_exclude_empty_records As Boolean = False) As String()
' ------------------------------------------------------------------------------------
' Returns the content of the file (vFile) - which may be provided as file object or
' full file name - as array by considering any kind of line break characters.
' ------------------------------------------------------------------------------------
    Const PROC  As String = "ToArray"
    
    On Error GoTo eh
    Dim ts      As TextStream
    Dim a       As Variant
    Dim a1()    As String
    Dim sSplit  As String
    Dim fso     As File
    Dim sFile   As String
    Dim i       As Long
    Dim j       As Long
    
    If Not Exists(ta_file, fso) _
    Then Err.Raise AppErr(1), ErrSrc(PROC), "The file object (vFile) does not exist!"
    
    '~~ Unload file into a test stream
    With New FileSystemObject
        Set ts = .OpenTextFile(fso.Path, 1)
        With ts
            On Error Resume Next ' may be empty
            sFile = .ReadAll
            .Close
        End With
    End With
    
    If sFile = vbNullString Then GoTo xt
    
    '~~ Get the kind of line break used
    If InStr(sFile, vbCr) <> 0 Then sSplit = vbCr
    If InStr(sFile, vbLf) <> 0 Then sSplit = sSplit & vbLf
    
    '~~ Test stream to array
    a = Split(sFile, sSplit)
    
    '~~ Remove any leading or trailing empty items
    mBasic.ArrayTrimm a
    
    If Not ta_exclude_empty_records Then
        ToArray = a
    Else
        '~~ Count empty records
        j = 0
        For i = LBound(a) To UBound(a)
            If Len(Trim$(a(i))) = 0 Then j = j + 1
        Next i
        j = UBound(a) - j
        ReDim a1(j - 1)
        j = 0
        For i = LBound(a) To UBound(a)
            If Len(Trim$(a(i))) > 0 Then
                a1(j) = a(i)
                j = j + 1
            End If
        Next i
        ToArray = a1
    End If
    
xt: Exit Function
    
eh: ErrMsg ErrSrc(PROC)
End Function

Public Function ToDict(ByVal td_file As Variant) As Dictionary
' ----------------------------------------------------------
' Returns the content of the file (td_file) - which may be
' provided as file object or full file name - as Dictionary
' by considering any kind of line break characters.
' ---------------------------------------------------------
    Const PROC  As String = "ToDict"
    
    On Error GoTo eh
    Dim ts      As TextStream
    Dim a       As Variant
    Dim dct     As New Dictionary
    Dim sSplit  As String
    Dim fso     As File
    Dim sFile   As String
    Dim i       As Long
    
    If Not Exists(td_file, fso) _
    Then Err.Raise AppErr(1), ErrSrc(PROC), "The file object (td_file) does not exist!"
    
    '~~ Unload file into a test stream
    With New FileSystemObject
        Set ts = .OpenTextFile(fso.Path, 1)
        With ts
            On Error Resume Next ' may be empty
            sFile = .ReadAll
            .Close
        End With
    End With
    
    If sFile = vbNullString Then GoTo xt
    
    '~~ Get the kind of line break used
    If InStr(sFile, vbCr) <> 0 Then sSplit = vbCr
    If InStr(sFile, vbLf) <> 0 Then sSplit = sSplit & vbLf
    
    '~~ Test stream to array
    a = Split(sFile, sSplit)
    
    '~~ Remove any leading or trailing empty items
    mBasic.ArrayTrimm a
    
    For i = LBound(a) To UBound(a)
        dct.Add i + 1, a(i)
    Next i
        
xt: Set ToDict = dct
    Exit Function
    
eh: ErrMsg ErrSrc(PROC)
End Function

Public Function ValueNames( _
                     ByVal vn_file As String, _
            Optional ByVal vn_section As String = vbNullString) As Dictionary
' ----------------------------------------------------------------------------
' Returns a Dictionary with all value names in a given file, when a section is
' provides only of this section.
' ----------------------------------------------------------------------------
    Const PROC = "ValueNames"
    
    On Error GoTo eh
    Dim asNames()       As String
    Dim dctSectionNames As Dictionary
    Dim dctNames        As Dictionary
    Dim i               As Long
    Dim lResult         As Long
    Dim sNames          As String
    Dim strBuffer       As String
    Dim v               As Variant
    Dim sSection        As String
    Dim sName           As String
    
    Set dctNames = New Dictionary
    Set dctSectionNames = New Dictionary
    Set ValueNames = New Dictionary    ' Empty in case no names are returned
    
    If vn_section <> vbNullString Then
        '~~> Retrieve the names for the provided Aspect
        strBuffer = Space$(32767)
        lResult = GetPrivateProfileString(lpg_ApplicationName:=vn_section _
                                        , lpg_KeyName:=vbNullString _
                                        , lpg_Default:=vbNullString _
                                        , lpg_ReturnedString:=strBuffer _
                                        , nSize:=Len(strBuffer) _
                                        , lpg_FileName:=vn_file _
                                         )
        sNames = Left$(strBuffer, lResult)
    
        If sNames <> vbNullString Then                                         ' If there were any names
            asNames = Split(sNames, vbNullChar)                      ' have them split into an array
            For i = LBound(asNames) To UBound(asNames)
                sName = asNames(i)
                If Len(sName) <> 0 Then
                    mDct.DctAdd add_dct:=dctNames, add_key:=sName, add_item:=sName, add_seq:=seq_ascending
                End If
            Next i
        End If
    Else
        '~~> Retrieve the names of all sections
        Set dctSectionNames = SectionNames(sn_file:=vn_file)
        For Each v In dctSectionNames
            sSection = v
            strBuffer = Space$(32767)
            lResult = GetPrivateProfileString(lpg_ApplicationName:=sSection _
                                            , lpg_KeyName:=vbNullString _
                                            , lpg_Default:=vbNullString _
                                            , lpg_ReturnedString:=strBuffer _
                                            , nSize:=Len(strBuffer) _
                                            , lpg_FileName:=vn_file _
                                             )
            sNames = Left$(strBuffer, lResult)
        
            If sNames <> vbNullString Then                                         ' If there were any names
                asNames = Split(sNames, vbNullChar)                      ' have them split into an array
                For i = LBound(asNames) To UBound(asNames)
                    sName = asNames(i)
                    If Len(sName) <> 0 Then
                        If Not dctNames.Exists(sName) Then
                            mDct.DctAdd add_dct:=dctNames, add_key:=sName, add_item:=sName, add_seq:=seq_ascending
                        End If
                    End If
                Next i
            End If
            
        Next v
    End If
        
    Set ValueNames = dctNames

xt: Exit Function
    
eh: ErrMsg ErrSrc(PROC)
End Function

Public Function Values( _
                 ByVal vl_file As String, _
        Optional ByVal vl_section As String = vbNullString) As Dictionary
' -----------------------------------------------------------------------
' Returns a Dictionary with value name as key and value as item - of all
' sections in a file or of a specific one when a section is provided.
' -----------------------------------------------------------------------
    Dim dctValueNames   As Dictionary
    Dim dctValues       As New Dictionary
    Dim vn              As Variant
    
    Set dctValueNames = mFile.ValueNames(vn_file:=vl_file, vn_section:=vl_section)
    For Each vn In dctValueNames
        If Not dctValues.Exists(vn) _
        Then mDct.DctAdd add_dct:=dctValues, add_key:=vn, add_item:=mFile.value(vl_file:=vl_file, vl_section:=vl_section, vl_value_name:=vn)
    Next vn
    Set Values = dctValues
    
End Function
