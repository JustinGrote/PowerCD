#requires -version 5.1

#region PowerCDBootstrap
$SCRIPT:PowerCDBootstrap = [scriptblock]::Create((iwr -useb 'https://gist.githubusercontent.com/JustinGrote/2d3fdbac302847be33de8021add524ad/raw/PowerCDBootstrap.ps1'))
. $PowerCDBootstrap
#endregion PowerCDBootstrap

task PowerCD.Test.Pester {
    Invoke-Pester
}