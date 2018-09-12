<#
    Helper function for merging hashtables
    <https://stackoverflow.com/questions/8800375/merging-hashtables-in-powershell-how>

    General instructions
    $table1, $table2 | Merge-Hashtables             #Duplicate values
    $table1, $table2 | Merge-Hashtables {$_[-1]}    #Overwrite $table1 values with $table2
    $table1, $table2 | Merge-Hashtables {$_[0]}     #Overwrite $table2 values with $table1
#>
Function Merge-Hashtables([ScriptBlock]$Operator) {
    $Output = @{}
    ForEach ($Hashtable in $Input) {
        If ($Hashtable -is [Hashtable]) {
            ForEach ($Key in $Hashtable.Keys) {$Output.$Key = If ($Output.ContainsKey($Key)) {@($Output.$Key) + $Hashtable.$Key} Else  {$Hashtable.$Key}}
        }
    }
    If ($Operator) {ForEach ($Key in @($Output.Keys)) {$_ = @($Output.$Key); $Output.$Key = Invoke-Command $Operator}}
    $Output
}
