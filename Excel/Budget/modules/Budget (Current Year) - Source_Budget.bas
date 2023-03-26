Attribute VB_Name = "Budget"
Option Base 1
Public Const SUMMARY_SHEET_NAME = "Summary"

Sub showViewForm()
Attribute showViewForm.VB_ProcData.VB_Invoke_Func = "r\n14"
    frmButtons.rbExpenses.Value = True
    frmButtons.Show
End Sub

Sub testgetDateFromTADSRecord()
    Dim d As Date
    
    d = getDateFromTADSRecord("Payment 9/9/16 applied", "1/1/2019", True)
    d = getDateFromTADSRecord("Tuition for Joshua Smith", "1/1/2019", True)
    d = getDateFromTADSRecord("EDP for Joshua Smith - 2016-10-10 thru 2016-10-23", "1/1/2019", True)
    d = getDateFromTADSRecord("EDP for Joshua Smith - 2016-10-10 thru 2016-10-23", "1/1/2019", False)
End Sub

Public Function getDateFromTADSRecord(description As String, defaultDate As String, Optional start As Boolean = True)
    Dim e As XlCVError
    Dim returnDate
    Dim beginString As String
    Dim endString As String
    
    returnDate = Between(description, " ", " ")
    If (IsDate(returnDate)) Then
        returnDate = CDate(returnDate)
    Else
        If (start) Then
            returnDate = Between(description, "- ", " thru")
        Else
            returnDate = After(description, "thru ")
        End If
        
        If IsDate(returnDate) Then
            returnDate = CDate(returnDate)
        Else
            If (IsDate(defaultDate)) Then
                returnDate = CDate(defaultDate)
            Else
                returnDate = Null
            End If
        End If
    End If
    
    getDateFromTADSRecord = returnDate
End Function


'
' Reads MINT transactions via a CSV in the Downloads folder, and refreshes a set of
' PowerQuery queries, and PivotTables for budget info
'
' 6/19/2019
'
Public Sub refreshTransactionData()
    Dim downloadPath As String
    Dim fullPath As String
    Dim fullDestPath As String
    Dim dataFiles As New Collection
    Dim index As Integer
    Dim sortedDataFiles()
    
    ' Determine the Downloads directory for the current user
    downloadPath = Environ("USERPROFILE")
    fullPath = downloadPath + "\Downloads\"
    
    ' Retrieve the list of transactions CSV files downloaded after the initial transactions.csv file
    ' i.e. those with (#) after their name
    filename = Dir(fullPath + "transactions (*.csv")
    While (filename <> "")
        dataFiles.Add filename
        filename = Dir()
    Wend
    
    Set fso = VBA.CreateObject("Scripting.FileSystemObject")
    
    ' Set the path for the CSV file to be loaded from PowerQuery
    fullDestPath = fullPath + "transactions.csv"
    Range("tblDataPath[Source]").Cells(1, 1).FormulaR1C1 = fullDestPath
    
    ' Use the latest CSV file with Mint transactions
    ' Copy the latest to the base filename if more than one exists, then
    ' delete the others
    If (dataFiles.Count > 0) Then
        sortedDataFiles = CollectionToArray(dataFiles)
        BubbleSort sortedDataFiles
        filename = fullPath + sortedDataFiles(UBound(sortedDataFiles))
        fso.CopyFile filename, fullDestPath, True
        
        If (fso.FileExists(fullDestPath)) Then
            For index = LBound(sortedDataFiles) To UBound(sortedDataFiles)
                filename = fullPath + sortedDataFiles(index)
                If (fso.FileExists(filename)) Then
                    fso.DeleteFile (filename)
                End If
            Next
        End If
    End If
    
    ' Refresh the PowerQueries followed by the pivot tables
    If (fso.FileExists(fullDestPath)) Then
        ActiveWorkbook.RefreshAll
        ActiveWorkbook.RefreshAll
    End If

End Sub


'
' Removes the temporary sheets generated by double clicking
' pivot table items (and anything else that starts with 'Sheet'
'
Sub deleteTempSheets()
    Dim Sh As Worksheet
    Dim tempSheets As New Collection
    Dim name As Variant
    Dim alertStatus As Boolean
    
    For Each Sh In Sheets
        If (Left(LCase(Sh.name), 5) = "sheet") Then
            tempSheets.Add Sh.name
        End If
    Next Sh

    alertStatus = Application.DisplayAlerts
    Application.DisplayAlerts = False
    
    For Each name In tempSheets
        Sheets(name).Delete
    Next name
    Application.DisplayAlerts = alertStatus
End Sub


'
' Generates the summary pivot view displaying transaction sums with categories
' as rows, and months as columns.
'
' Also includes a number of filters at the top of the pivot
'
Function generateSummaryPivot() As Worksheet
    Dim rngSrcData As Range
    Dim strPivotSheetName As String
    Dim shtPivotSheet As Worksheet
    Dim rngPivotDest As Range
    Dim strPivotName As String
    Dim colColFields As New Collection
    Dim colRowFields As New Collection
    Dim colFilterFields As New Collection
    Dim colSumFields As New Collection
    Dim strTransactions As String
    Dim pvt As PivotTable
    
    strPivotSheetName = SUMMARY_SHEET_NAME
    strTransactions = "tblTransactions"
    strPivotName = "pvt" + strPivotSheetName
    
    Set shtPivotSheet = GetDataSheet(strPivotSheetName, True)
    Set rngSrcData = Range(strTransactions + "[#all]")
    Set rngPivotDest = shtPivotSheet.Cells(1, 1)
    colColFields.Add "Date"
    colFilterFields.Add "Tax Related"
    colRowFields.Add "Parent"
    colRowFields.Add "Category"
    colFilterFields.Add "Parent.1"
    colFilterFields.Add "Category.1"
    colFilterFields.Add "Frequency"
    colFilterFields.Add "Type"
    colSumFields.Add "Sum of Amount"
    
    Set pvt = MakePivot(rngSrcData, rngPivotDest, strPivotName, colColFields, colRowFields, colFilterFields, colSumFields)
    
    pvt.PivotFields("Date").AutoGroup
    
    pvt.PivotFields("Quarters").Orientation = xlHidden
    
    pvt.PivotFields("Years").Orientation = xlPageField
    pvt.PivotFields("Years").Position = colFilterFields.Count + 1
        
    pvt.DataBodyRange.NumberFormat = _
        "_([$$-en-US]* #,##0.00_);_([$$-en-US]* (#,##0.00);_([$$-en-US]* ""-""??_);_(@_)"
        
    Set generateSummaryPivot = pvt.Parent
End Function



Sub setSummaryFilters(Optional strParameters = "")
    Dim wksSummary As Worksheet
    Dim strPivotName As String
    Dim strYear As String
    Dim toggle As dsFilterSettings
    Dim colItems As New Collection
    
    strPivotName = "pvt" + SUMMARY_SHEET_NAME
        
    Set wksSummary = GetDataSheet(SUMMARY_SHEET_NAME, False)
        
    If (wksSummary Is Nothing) Then
        Set wksSummary = generateSummaryPivot
    End If
    
    wksSummary.Activate
    
    clearAllFilters
    
    ' Set the year filter to the current year
    ClearCollection colItems
    strYear = CStr(Year(Now()))
    ' strYear = "2022"
    colItems.Add strYear
    SetPivotFilterValues strPivotName, "Years", Nothing, colItems, dsOnExclusive

    ' Set Income and/or Expenses
    ClearCollection colItems
    
    If (InStr(strParameters, "I")) Then
        colItems.Add "Income"
    End If
    
    If (InStr(strParameters, "E")) Then
        colItems.Add "Expense"
    End If
        
    SetPivotFilterValues strPivotName, "Type", Nothing, colItems, dsOnExclusive

    ClearCollection colItems
    colItems.Add "Reimbursable Expense"
    SetPivotFilterValues strPivotName, "Category.1", Nothing, colItems, dsOff
        
    ' Add or remove projected (budget) items
    ClearCollection colItems
    colItems.Add "projected"
    If (InStr(strParameters, "P")) Then
        toggle = dsOn
    Else
        toggle = dsOff
    End If
    
    SetPivotFilterValues strPivotName, "Subcategory.3", Nothing, colItems, toggle

    ' Add or remove annual items
    ClearCollection colItems
    colItems.Add "1"
    If (InStr(strParameters, "A")) Then
        toggle = dsOn
    Else
        toggle = dsOff
    End If
    
    SetPivotFilterValues strPivotName, "Frequency", Nothing, colItems, toggle

    ' Add or remove vacations, projects, and special occasions items
    ClearCollection colItems
    colItems.Add "Misc Expenses"
    If (InStr(strParameters, "V")) Then
        toggle = dsOn
    Else
        toggle = dsOff
    End If
    
    SetPivotFilterValues strPivotName, "Parent.1", Nothing, colItems, toggle
    
    ' Add or remove Tax Related items
    If (InStr(strParameters, "T")) Then
        ClearCollection colItems
        colItems.Add "yes"
        toggle = dsOnExclusive
        
        SetPivotFilterValues strPivotName, "Tax Related", Nothing, colItems, toggle
    End If
    
    
    ActiveWindow.ScrollRow = 1
    ActiveWindow.SplitRow = 10
    ActiveWindow.FreezePanes = True
End Sub

Sub filterMonthlyExpenses()
    Dim strPivotName As String
    Dim colExclude As New Collection
    Dim pvt As PivotTable
    
    strPivotName = "pvtSummary"
    
    clearAllFilters
    
    Set pvt = ActiveSheet.PivotTables(strPivotName)
    colExclude.Add "Expense"
    SetPivotFilterValues strPivotName, "Type", Nothing, colExclude, dsOnExclusive
    
    ClearCollection colExclude
    colExclude.Add "Transfer"
    SetPivotFilterValues strPivotName, "Parent.1", Nothing, colExclude, dsOff
    
    ClearCollection colExclude
    colExclude.Add "Charity"
    SetPivotFilterValues strPivotName, "Category", Nothing, colExclude, dsOff
        
    frmButtons.chkIncludeAnnual.Enabled = True
    
    filterAnnualExpenses
    filterMiscExpenses
End Sub


Sub filterAllAnnualExpenses()
    Dim strPivotName As String
    Dim colExclude As New Collection
    Dim pvt As PivotTable
    
    strPivotName = "pvtSummary"
    Set pvt = ActiveSheet.PivotTables(strPivotName)
    
    clearAllFilters
    
    colExclude.Add "Expense"
    SetPivotFilterValues strPivotName, "Type", Nothing, colExclude, dsOnExclusive
    
    ClearCollection colExclude
    colExclude.Add "Transfer"
    SetPivotFilterValues strPivotName, "Parent.1", Nothing, colExclude, dsOff
    
    ClearCollection colExclude
    colExclude.Add "Annual"
    SetPivotFilterValues strPivotName, "Frequency", Nothing, colExclude, dsOnExclusive
    
    frmButtons.chkIncludeAnnual.Value = True
    frmButtons.chkIncludeAnnual.Enabled = False
'    filterAnnualExpenses
    filterMiscExpenses
End Sub


'Sub filterIncome()
'    Dim strPivotName As String
'    Dim colItems As New Collection
'    Dim pvt As PivotTable
'
'    strPivotName = "pvtSummary"
'    Set pvt = ActiveSheet.PivotTables(strPivotName)
'
'    clearAllFilters
'
'    colItems.Add "Income"
'    SetPivotFilterValues strPivotName, "Type", Nothing, colItems, dsOnExclusive
'
'    ClearCollection colItems
'    colItems.Add "Transfer"
'    SetPivotFilterValues strPivotName, "Parent.1", Nothing, colItems, dsOff
'
'End Sub


Sub filterExpenses()
    Dim strPivotName As String
    Dim colItems As New Collection
    Dim pvt As PivotTable
    
    strPivotName = "pvtSummary"
    Set pvt = ActiveSheet.PivotTables(strPivotName)
    
    clearAllFilters
    
    colItems.Add "Expense"
    SetPivotFilterValues strPivotName, "Type", Nothing, colItems, dsOnExclusive
    
    ClearCollection colItems
    colItems.Add "Transfer"
    SetPivotFilterValues strPivotName, "Parent.1", Nothing, colItems, dsOff
End Sub


Sub filterIncomeAndExpenses()
    Dim strPivotName As String
    Dim colItems As New Collection
    Dim pvt As PivotTable
    
    strPivotName = "pvtSummary"
    Set pvt = ActiveSheet.PivotTables(strPivotName)
    
    clearAllFilters
    
    colItems.Add "Income"
    colItems.Add "Expense"
    SetPivotFilterValues strPivotName, "Type", Nothing, colItems, dsOnExclusive

    ClearCollection colItems
    colItems.Add "Transfer"
    SetPivotFilterValues strPivotName, "Parent.1", Nothing, colItems, dsOff
End Sub


Sub filterAnnualExpenses()
    Dim colValues As New Collection
    Dim toggle As dsFilterSettings
    Dim strPivotName As String
    
    strPivotName = "pvtSummary"
    
    colValues.Add "Annual"
    If Not (frmButtons.chkIncludeAnnual.Value = True) Then
        toggle = dsOff
    Else
        toggle = dsOn
    End If
    
    SetPivotFilterValues strPivotName, "Frequency", Nothing, colValues, toggle
End Sub

Sub filterMiscExpenses()
    Dim colValues As New Collection
    Dim toggle As dsFilterSettings
    Dim strPivotName As String
    
    strPivotName = "pvtSummary"
    
    colValues.Add "Misc Expenses"
    If Not (frmButtons.chkIncludeMisc.Value = True) Then
        toggle = dsOff
    Else
        toggle = dsOn
    End If
    SetPivotFilterValues strPivotName, "Parent.1", Nothing, colValues, toggle
End Sub


Sub clearAllFilters()
    Dim index As Integer
    Dim pvt As PivotTable
    
    For index = 1 To ActiveSheet.PivotTables.Count
        Set pvt = ActiveSheet.PivotTables.Item(index)
        pvt.clearAllFilters
    Next
End Sub


Sub setFilters()
    Dim strPivotName As String
    Dim colDisabled As New Collection
    
    strPivotName = "TestPivot"
    
    colDisabled.Add "Charity"
    colDisabled.Add "Credit Card Payment"
    colDisabled.Add "Credit Card Payment"
    
    SetPivotFilterValues strPivotName, "Category.1", Nothing, colEnabled, dsOn
End Sub

Sub tableSelect()
    Dim rng As Range
    
    Set rng = Range("tblTransactions[#all]")
    Debug.Print (rng.Address)
End Sub
