Attribute VB_Name = "ExportTools"
Option Explicit

' Set EXPORT_PATH to '' to export to %TEMP%
' Public Const EXPORT_PATH = "C:\source\Projects\Excel"
Public Const EXPORT_PATH = ""

' BUGBUG: Retrieve the export path from a cell in the spreadsheet

Sub main()
' This macro enumerates the open workbooks and exports the code modules and queries
' associated with each workbook.
'
' Spec: https://tinyurl.com/2uaerce8
'
' Revisions
' ---------------------------------------------------------------------------------------
'  3/26/2023    Created by Dave Smith
'  4/27/2023    Added debug lines to list exported files and path
'               Added constant for EXPORT_PATH and fixed up variable names
'               Rolled back changes to export all files to %TEMP%
'
'
    Dim wb As Workbook
    
    For Each wb In Application.Workbooks
        Debug.Print ("*** Exporting macros and queries from " + wb.Name + " ***")
        ExportModules wb, EXPORT_PATH
        ExportQueries wb, EXPORT_PATH
    Next
End Sub

Sub ExportQueries(wb As Workbook, Optional ByVal szExportPath As String = "", Optional create As Boolean = True)
'
'   Enumerates and exports all power queries associated with the specified workbook
'
    Dim query_list As Queries
    Dim query As WorkbookQuery
    Dim i As Integer
    Dim n As Integer
    Dim current_date As Date
    Dim full_file_path As String
    
    If szExportPath = "" Then
        szExportPath = wb.path
        
        If IsOneDrivePath(szExportPath) Then
            szExportPath = GetTempPath() + "\" + GetBaseName(wb.Name)
        End If
    End If
    
    current_date = Now
    
    szExportPath = szExportPath + "\queries"
            
    Set query_list = wb.Queries
    If query_list.Count > 0 Then
        n = FreeFile()
        
        full_file_path = szExportPath + "\" + GetBaseName(wb.Name) + "_queries.txt"
        Debug.Print ("  " + full_file_path)
        
        CreateFolderPathEx (szExportPath)
        Open full_file_path For Output As #n
        
        Print #n, "// Order of queries for " + wb.Name + " as of " + FormatDateTime(current_date, vbShortDate)
        Print #n, "//"
        For i = 1 To query_list.Count
            Print #n, "// " + query_list(i).Name
        Next
        
        Print #n, "//" + vbNewLine
        
        For i = 1 To query_list.Count
            Print #n, "////////////////////////////////////////////////////////////////////////"
            Print #n, "// " + query_list(i).Name
            Print #n, "////////////////////////////////////////////////////////////////////////"
            Print #n, query_list(i).Formula
            Print #n, vbNewLine + vbNewLine
        Next
        
        Close #n
    End If
End Sub


Sub ExportModules(wb As Workbook, Optional ByVal szExportPath As String = "")
    Dim vbproj As VBIDE.VBProject
    Dim vbcomp As VBIDE.VBComponent
    Dim ws As Worksheet
    Dim export_name As String
    
    Set vbproj = wb.VBProject
    If szExportPath = "" Then
        szExportPath = wb.path
        
        If IsOneDrivePath(szExportPath) Then
            szExportPath = GetTempPath() + "\" + GetBaseName(wb.Name)
        End If
    End If
    
    szExportPath = szExportPath + "\modules"
    
    For Each vbcomp In vbproj.VBComponents
        If (vbcomp.Type = vbext_ct_ClassModule) Or _
        (vbcomp.Type = vbext_ct_MSForm) Or _
        (vbcomp.Type = vbext_ct_StdModule) Then
            export_name = Left(wb.Name, InStr(wb.Name, ".") - 1) + "_" + vbcomp.Name
            ExportVBComponent vbcomp, szExportPath, export_name
        End If
    Next vbcomp
End Sub

    
Function ComponentTypeToString(ComponentType As VBIDE.vbext_ComponentType) As String
    Select Case ComponentType
        Case vbext_ct_ActiveXDesigner
            ComponentTypeToString = "ActiveX Designer"
        Case vbext_ct_ClassModule
            ComponentTypeToString = "Class Module"
        Case vbext_ct_Document
            ComponentTypeToString = "Document Module"
        Case vbext_ct_MSForm
            ComponentTypeToString = "UserForm"
        Case vbext_ct_StdModule
            ComponentTypeToString = "Code Module"
        Case Else
            ComponentTypeToString = "Unknown Type: " & CStr(ComponentType)
    End Select
End Function

Public Function ExportVBComponent(vbcomp As VBIDE.VBComponent, _
                FolderName As String, _
                Optional filename As String, _
                Optional OverwriteExisting As Boolean = True) As Boolean
    '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
    ' This function exports the code module of a VBComponent to a text
    ' file. If FileName is missing, the code will be exported to
    ' a file with the same name as the VBComponent followed by the
    ' appropriate extension.
    '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
    Dim Extension As String
    Dim FName As String
    
    Extension = GetFileExtension(vbcomp:=vbcomp)
    If Trim(filename) = vbNullString Then
        FName = vbcomp.Name & Extension
    Else
        FName = filename
        If InStr(1, FName, ".", vbBinaryCompare) = 0 Then
            FName = FName & Extension
        End If
    End If
    
    ' Append a backslash to the end of the path if necessary
    If StrComp(Right(FolderName, 1), "\", vbBinaryCompare) = 0 Then
        FName = FolderName & FName
    Else
        FName = FolderName & "\" & FName
    End If
    
    If Dir(FName, vbNormal + vbHidden + vbSystem) <> vbNullString Then
        If OverwriteExisting = True Then
            Kill FName
        Else
            ExportVBComponent = False
            Exit Function
        End If
    End If
    
    Debug.Print ("  " + FolderName + "\" + filename)
    CreateFolderPathEx (FolderName)
    vbcomp.Export filename:=FName
    ExportVBComponent = True
    
End Function
    
Public Function GetFileExtension(vbcomp As VBIDE.VBComponent) As String
    '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
    ' This returns the appropriate file extension based on the Type of
    ' the VBComponent.
    '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
    Select Case vbcomp.Type
        Case vbext_ct_ClassModule
            GetFileExtension = ".cls"
        Case vbext_ct_Document
            GetFileExtension = ".cls"
        Case vbext_ct_MSForm
            GetFileExtension = ".frm"
        Case vbext_ct_StdModule
            GetFileExtension = ".bas"
        Case Else
            GetFileExtension = ".bas"
    End Select
    
End Function


