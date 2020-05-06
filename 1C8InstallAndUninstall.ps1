# ��������: ������ ��������� ������������� � ������� ��������� 1�
# �����: Dim
# ������: 1.07
# ������� ��������� �� ���������. ������ ��������� ����� �������� ������� �� ������� ����� �����������
param([string]$dd = "\\1CServer\1CDistr", # ���� �� �������� � �������������� �������� 1� 8
      [string]$dl = "\\1CServer\1CLogs", # ���� �� �������� � ������� ����� ������������ ���� ��������� � ��������
      [string]$ip = "last", # ��������� ���������� �������� ������� ����� �������� ������
      [string]$dp = "ael", # ��������� �������� ������������ � �������� ����� �������� ������
      [string]$iod = "DESIGNERALLCLIENTS=1 THINCLIENT=1 THINCLIENTFILE=1") # ��������� ���������� ��� ��������� ����� ���������

# ����������� ��� ���������� � ����� ������������ ����
$DistribDir = $dd
$DirLog = $dl
$InstallPar = $ip
$DeletPar = $dp
$InstallOptDistr = $iod

# ��������������� ���������
$ScriptVersion = "1.07"
$RegExpPatternNumPlatform = "^(\d+\.\d+)\.(\d+\.\d+)$"
$RegExpPatternNameFolderDistrib = "^(\d+\.\d+)\.(\d+\.\d+)(|-32|-64)$"

#======================================================================================
#======================================================================================
#================ ������ ������� ======================================================

# ������� ������ ��� ������ � ����������� ����������� ������� � ����� ����������
# �������� ������: ���� �� ����� ����������� � ������ ������� ���� � ���� ��������
# ������������ ���������: ���
Function WriteLog($LogFile, $str) {
    ((Get-Date -UFormat "%Y.%m.%d %T") + " " + $str) >> $LogFile
}

# ��������� ������ ������� ��������� ����� ����������� ������� ����������
# �������� ������: ���� �� ����� �����������
# ������������ ���������: ���
Function EndLogFile($LogFile) {
    WriteLog $LogFile "��������� ������ �������" 
    "---------------------------------------------------------------------------------" >> $LogFile 
    Exit
}

# ������ ������� ���������� � ������ ������������� ������ ��� ������ � ��������� ��� ����� �������
# �������� ������: ���
# ������������ ���������: ������ ���� �� ��� �����
Function ErrDirLog {
    $LogFile = $env:LOCALAPPDATA + "\1C8InstallAndUninstall.log"
    # �������� ������������� ����� ��� ����������� � ��������� ����
    If (-not (Test-Path -path $LogFile)) {
        # ���� �� ����������, �������� ���
        $LogFile = New-Item -Path $LogFile -ItemType "file"
    }
    Return $LogFile
}

# ������� ������� ��� ������������� ��������� 1�:����������� 8 �� ����������
# �������� ������: ���
# ������������ ���������: ������
Function SearchInstallPlatformsOnComputer {
    Return Get-WmiObject Win32_Product | Where-Object {$_.Name -match "^(1�|1C)"}   
}

# ������� ��������� ������� ��������� �� ����������
# �������� ������: ������ ��� ������������� ��������, ������� ���������
# ������������ ���������: ������� ��������
Function PlatformInstallOnComputer ($AllInstallPlatformOnComputer, $SearchPlatform) {
    $FlagPlatformInstall = $false
    ForEach ($PlatformOnComputer in $AllInstallPlatformOnComputer) {
        If ($PlatformOnComputer.Version -match $SearchPlatform) {
            $FlagPlatformInstall = $true        
        }
    }
    Return $FlagPlatformInstall   
}

# ��������������� �������� 1�:����������� � ����������
# �������� ������: ��� ��������, ������ ��������, ���� � ����� � ������
# ������������ ���������: ���
Function UninstallPlatform ($Product, $LogFile) {
    $IdentifyingNumber = $Product.IdentifyingNumber
    $Version = $Product.Version
    WriteLog $LogFile ("�������� 1�:�����������, ������ " + $Version)

    Start-Process -Wait -FilePath msiexec -ArgumentList  ('/uninstall "' + $IdentifyingNumber + '" /quiet /norestart /Leo+ "' + $LogFile + '"')
}

# ��������������� ��������� 1�:����������� �� ���������
# �������� ������: ���� �� ����� � �����������, ����� ���������, ������ ���������������� ��������, ���� � ����� � ������
# ������������ ���������: ���
Function InstallPlatform ($DistribDir, $InstallOptDistr, $ProductVer, $LogFile){
    WriteLog $LogFile ("��������� 1�:�����������, ������ " + $ProductVer)

    # ������ ���� ������� ���������� ���� �� ����������� ������� ���������, ����� � ����� �������
    $FlagAttemptInstall = $false
      
    # ��������� �� �������� �������
    If ( (Get-WmiObject Win32_OperatingSystem).OSArchitecture -match "32") {
        $OSArch = "32"
    } else {
        $OSArch = "64"
    }
    
    # �������� ����������� ������ � ������� ������� ���� �� ��������� ����� ����� � ����������� �� ����������� �������
    If ($OSArch -match "32") {
        $InstallFolders = @( ($DistribDir + $ProductVer + "-32\") , ($DistribDir + $ProductVer + "\") )
    } else {
        $InstallFolders = @( ($DistribDir + $ProductVer + "-64\"), ($DistribDir + $ProductVer + "\") )
    }

    ForEach ($InstallFolder in $InstallFolders) {
        # �������� ������������� ������ �����, ����� �� ������ ������� ������������� � ������������� �����
        If ( -not (Test-Path -Path $InstallFolder) ) {
            Continue
        }
        
        # �������� �� ���� �� ������������ ������� ��������� ������� �����
        If ( $FlagAttemptInstall ) {
            Continue
        }
            
        # ����� ������������ msi ����
        $InstallMSI = "....."
        $InstallMSI = (Get-ChildItem -Path $InstallFolder | Where-Object {$_.Name -match "^(1CEnterprise 8 \(x86-64\)|1CEnterprise 8|1CEnterprise 8 Thin client \(x86-64\)|1CEnterprise 8 Thin client)\.msi$"}).Name
        If ($InstallMSI -match "^$") {
            WriteLog $LogFile ('�� ������ ������������ msi ���� � �������� "' + $InstallFolder + '". ��������� ��������� �� ������� �������� ����������.')
            Continue
        }        
        $InstallMSI = $InstallFolder + $InstallMSI
        
        # �������� ��������� ����
        If (-not (Test-Path -Path $InstallMSI) ) {
            WriteLog $LogFile ('��� ������ ����� msi ��������� ������. ��������� ��������� �� ������� �������� ����������.')
            Continue
        }

        # �������� ������������ ��������� ������ � ������ ����������� � ����� � ����������
        $PathSetupFile = $InstallFolder + "setup.ini"
        If (-not (Test-Path -Path $PathSetupFile) ) {
            WriteLog $LogFile ('�� ������ ���� setup.ini � �������� "' + $InstallFolder + '". ��������� ��������� �� ������� �������� ����������.')
            Continue
        }

        # ������� ������ �� ����� setup.ini
        $SetupFile = Get-Content $PathSetupFile
        # �������� ����� ������ ������� � ����� setup.ini
        If ( -not ( ([string]$SetupFile).Contains("ProductVersion=$ProductVer") ) ) {
            WriteLog $LogFile ('������ ���� ����������� ������ ' + $ProductVer + ', �� � �������� "' + $InstallFolder + '" ���������� ������ ������ ������ ���������. ��������� ��������� �� ������� �������� ��������.')
            Continue
        }

        # �������� ������ ��������� � ������ ������������ �������, �.�. ���������� ���������� 64 ������ ����� ��������� �� 32 ������ ������ �������
        If ( ( $OSArch -match "32" ) -and ( ([string]$SetupFile).Contains("Product=1C:Enterprise 8 (x86-64)" -or ([string]$SetupFile).Contains("Product=1C:Enterprise 8 Thin client (x86-64)") ) ) ) {
            WriteLog $LogFile ('� �������� "' + $InstallFolder + '" ���������� 64-������ ������ ���������, ���������� ���������� 64-������ ������ ��������� �� 32-������ �������')
            Continue
        }
        
        # �������� ����� ���������, ���� ��� �� ������������� �������, �� ������� ��������� ���� �����������
        If ( -not ($InstallOptDistr -match "DESIGNERALLCLIENTS=(0|1) THINCLIENT=(0|1) THINCLIENTFILE=(0|1)") ) {
            WriteLog $LogFile ('���������� ������� �������� "-iod" ����� �� ���������� �������� "' + $InstallOptDistr + '". ����� ����������� ��� ���������� ���������� ���������.')
            $InstallOptDistr = "DESIGNERALLCLIENTS=1 THINCLIENT=1 THINCLIENTFILE=1"
        }    
     
        # ��������� ��������� Visual C++ Redistributable
        $vc_redist = "....."
        $vc_redist = (Get-ChildItem -Path $InstallFolder | Where-Object {$_.Name -match "^vc_redist.*.exe$"}).Name
        If ($vc_redist -match "^$") {
            WriteLog $LogFile ('�� ������ ���� ��� Visual C++ Redistributable � �������� "' + $InstallFolder + '". ��������� ��������� �����������.')
        } else {        
            $vc_redist = $InstallFolder + $vc_redist
            # �������� ��������� ����
            If (-not (Test-Path -Path $vc_redist) ) {
                WriteLog $LogFile ('��� ������ ����� ��� Visual C++ Redistributable ��������� ������. ��������� ��������� �����������.')                
            }  else {
            Start-Process -Wait -FilePath $vc_redist -ArgumentList ('/install /quiet /norestart')
            }
        }        

        # ������ ����� �������
        If ( (Test-Path -Path ($InstallFolder + 'adminstallrestart.mst')) -and (Test-Path -Path ($InstallFolder + '1049.mst')) ) {
            # ����� ������� �������, ���������� ����������
            Start-Process -Wait -FilePath  msiexec -ArgumentList ('/jm "' + $InstallMSI + '" /t adminstallrestart.mst;1049.mst /quiet /norestart /Leo+ "' + $LogFile + '"')
        } else {
            # ����� ������� �� �������, ������� ��� � �� ����� �������������� ����������
            WriteLog $LogFile ('�� ������ ���� ������� adminstallrestart.mst ��� 1049.mst � �������� "' + $InstallFolder + '" ��������� ����� ����������� ��� ����������')
        }
        
        # ��������� ���������������� ���������
        Start-Process -Wait -FilePath msiexec -ArgumentList ('/package "' + $InstallMSI + '" ' + $InstallOptDistr + ' /quiet /norestart /Leo+ "' + $LogFile + '"')    
        $FlagAttemptInstall = $true
    }
    
    # ������� ��� ��������� �� ������ ��������� ��� ������� �� ������������, ���� �� ���� ������� ���������
    If ( (-not $FlagAttemptInstall) -and (Test-Path ($DistribDir + $ProductVer + "-32\") ) -and ($OSArch = "64") ) {
        WriteLog $LogFile '��� 64-������ ������� �� ������������ ��������� �� �������� ���������������� ��� 32-������ �������'
    }
    If ( (-not $FlagAttemptInstall) -and (Test-Path ($DistribDir + $ProductVer + "-64\") ) -and ($OSArch = "32") ) {
        WriteLog $LogFile '��� 32-������ ������� �� ������������ ��������� �� �������� ���������������� ��� 64-������ �������'
    }

    # �������� ������������ �� ����������� ��� ���������
    $NewInstallPlatformsOnComputer = SearchInstallPlatformsOnComputer
    If ( -not (PlatformInstallOnComputer $NewInstallPlatformsOnComputer $ProductVer)) {
        WriteLog $LogFile "����� ��������� �� ���� ������� ��������� $ProductVer �� ������ ����������. ������ ������� ��������."
        EndLogFile $LogFile
    }
}

#================= ����� ������� ======================================================
#======================================================================================
#======================================================================================

# ������� ���������� ���� � ��������� � ������ ����� ������� � ��� �������� ���� � �����
If (-not $DistribDir.EndsWith("\")) {$DistribDir = $DistribDir + "\"}
If (-not $DirLog.EndsWith("\")) {$DirLog = $DirLog + "\"}

# ��� ������� �� ����������� ����� ���� ��� ���� ��������������� ����� ����������. � ����� ���� �� ����� ���� 2 ���������� � ����������� �������
$LogFile = $DirLog + $env:COMPUTERNAME + ".log"
# �������� ��������������� ���������� � ��������� ������
$StrErr = ""

# �������� ������������� ����� ��� ����������� � ��������� ����
If (Test-Path -path $LogFile) {
    # ���� ����������, �������� � ���� ��������
    Try {
        Out-File -FilePath $LogFile -InputObject "" -Append -ErrorAction Stop
    } Catch {
        # ������ ������
        $StrErr = "�� ������� �������� ���� � $LogFile"
        # ������ ���� � ����� �����������
        $LogFile = ErrDirLog
    }
} else {
    # ���� �� ����������, ���������� ��������� ���
    Try {
        $LogFile = New-Item -Path $LogFile -ItemType "file" -ErrorAction Stop
    } Catch {
        # ������ ������
        $StrErr = "�� ������� ������� ���� $LogFile"
        # ������� ���� � �������� ��������� ��� ������� �� �������, ������ ���� � ����� �����������
        $LogFile = ErrDirLog
    }
}

# ������� ������ � ������ ������ �������
" " >> $LogFile
"---------------------------------------------------------------------------------" >> $LogFile
"������ �������: $ScriptVersion" >> $LogFile
"��������� ������� �������: -dd '$dd' -dl '$dl' -dp '$dp' -ip '$ip' -iod '$iod'" >> $LogFile

WriteLog $LogFile "������ ������ �������"
If ($StrErr.Length -ne 0) {WriteLog $LogFile $StrErr}    
    
# �������� ������������� ���������� ��������. ��������� ��������� � �������� ��������� � ��������� "no"?
If ($InstallPar -match "^no$" -and $DeletPar -match "^no$") {
    WriteLog $LogFile '��������� ��������� � �������� ���������� � ��������� "no", �� ����� �������� ��������� �� ���������.'
    EndLogFile -LogFile $LogFile
}

# ���������� �������������� �������� �������� ���� ������������� ���� � ������ �������� �������� -dp "all"
If ($DeletPar -match "^all$") {
    WriteLog $LogFile '�������� �������� ���������� � ��������� "all", ��� ��������� ��������� ������������ � ������������� �������� ���� ��������� �� ���������� �������� 1� �����������.'
	$InstallPlatformsOnComputer = SearchInstallPlatformsOnComputer
	# ��������������� ������ ��� ���������
    ForEach ($PlatformOnComputer in $InstallPlatformsOnComputer) {
        UninstallPlatform -Product $PlatformOnComputer -LogFile $LogFile
    }
    EndLogFile -LogFile $LogFile
}

# �������� �������� ��� ����������
If ( -not (  ($InstallPar -match "^no$") -or ($InstallPar -match "^last$") -or ($InstallPar -match $RegExpPatternNumPlatform) ) ) {
    WriteLog $LogFile "�������� ��������� ���������� �� �������� �� ��� ���� �� ���������. ������ ������� ��������."
    EndLogFile -LogFile $LogFile
}

# �������� �������� ��� ��������
If ( -not ( ($DeletPar -match "^no$") -or ($DeletPar -match "^ael$") -or ($DeletPar -match $RegExpPatternNumPlatform) -or ($DeletPar -match "^all$") ) ) {
    WriteLog $LogFile "�������� ��������� �������� �� �������� �� ��� ���� �� ���������, �������� ������������� �� �����."
}

# ����� ���� �������� ���� ����� ��������� ��� ������� ���� �� ���� �� ���������� "x.x.x.x" ��� "last" ��� "ael"
# ������� ������ � �������� � ��������������, ��� ������� ����, ��� ���������� ������ �� ���������� ��� ������������ ������ � �������� � ��������������
If (-not (Test-Path -path $DistribDir)) {
    # ������ � �������� � �������������� 1� ������ ��� �� ����������, ������� ��� � ������ �� �������
    WriteLog $LogFile "�� ������� �������� ������ � �������� � �������������� 1�, ��������� ���� � ����� ������� $DistribDir"
    EndLogFile -LogFile $LogFile
}

# ����� ��� ������������� ��������� 1� �� ����������
# ���������� ���������� ��������. ���� �������� ����������� � �������� ��� ������, �� ��������
$InstallPlatformsOnComputer = SearchInstallPlatformsOnComputer

# ��������� ��������� ���� ���� �������� ���������� ���������� ������, �� ����� ���� �������� ��� ������ ������ �� ����������� �� ���������
If ($InstallPar -match $RegExpPatternNumPlatform) {
    If (PlatformInstallOnComputer $InstallPlatformsOnComputer $InstallPar) {
        WriteLog $LogFile "��������� 1� ������ $InstallPar ��� �����������"
    } else {    
        InstallPlatform -DistribDir $DistribDir -InstallOptDistr $InstallOptDistr -ProductVer $InstallPar -LogFile $LogFile
    }
}

# �������� �������� �� ��������� "last" ��� "eal"
If ( ($InstallPar -match "^last$") -or ($DeletPar -match "^ael$") ) {

    # ��������������� ����������
    If ($DeletPar -match "^ael$") { 
        [array]$NeedUninstallPlatforms = @()
    }
    $CountPlatform = 0
    $MaxNumMajor = 0
    $MaxNumMinor = 0

    # �������� �� ����� � �������������� � ����� ������� �� ������, � ��� �� �������� ������ �������� ������� ������ ���� �������
    ForEach ($Element in (Get-ChildItem -Path $DistribDir)) {
        If (($Element.Mode -match "d*") -and ($Element.Name -match $RegExpPatternNameFolderDistrib)) {        
            $CountPlatform = $CountPlatform + 1
            # ����� ������� ���������
            If ([double]$Matches[1] -eq $MaxNumMajor) {
                If ([double]$Matches[2] -ge $MaxNumMinor) {
                    $HighPlatform = $Matches[1] + '.' + $Matches[2]
                    $MaxNumMinor = [double]$Matches[2]
                }
            }
            If ([double]$Matches[1] -gt $MaxNumMajor) {
                $HighPlatform = $Matches[1] + '.' + $Matches[2]
                $MaxNumMajor = [double]$Matches[1]
                $MaxNumMinor = [double]$Matches[2]
            }
            # ������� ��������� �� ��������, ���� ��� ��������� � ������������� �� ����������
            If ($DeletPar -match "^ael$") { 
                ForEach ($PlatformOnComputer in $InstallPlatformsOnComputer) {
                    If ($Element.Name -eq $PlatformOnComputer.Version) {
                        $NeedUninstallPlatforms = $NeedUninstallPlatforms + $PlatformOnComputer 
                    }

                }
            }
        }
    }
    
    # ��������� �� ���-�� �������� �������������
    If ($CountPlatform -eq 0) {
        WriteLog $LogFile "�� ������� �� ������ ������������ 1� ����������� � $DistribDir ��������� � ������ -ip 'last' ��� �������� � ������ -dp 'ael' �� ����� �������������."
    } elseif ($CountPlatform -eq 1) {
        If ($InstallPar -match '^last$' ) {
            # �������� �� ���������� �� ������� �����������, ����� �������� ��������� ���������
            If (PlatformInstallOnComputer $InstallPlatformsOnComputer $HighPlatform) {
                WriteLog $LogFile "������ ������ ���� ����������� $HighPlatform, �� �� ��� ����������, ��������� ��������� ������������� �� �����."
            } else {            
                InstallPlatform -DistribDir $DistribDir -InstallOptDistr $InstallOptDistr -ProductVer $HighPlatform -LogFile $LogFile
            }
        }
        If ($DeletPar -match '^ael$') {
            WriteLog $LogFile "������ ������ ���� ���������� $HighPlatform. �������� ����������� �� �����, �.�. ������ ����������� �������� ��������� (�������)."
        }
    } else {
        # ��������� ������� ������, ���� ��� ���������
        If ($InstallPar -match '^last$') {
            # ��������, �� ����������� �� ��� ������ ������ �� ����������
            If (PlatformInstallOnComputer $InstallPlatformsOnComputer $HighPlatform) {
                WriteLog $LogFile "��������� (�������) ��������� $HighPlatform ��� �����������."
            } else {            
                InstallPlatform -DistribDir $DistribDir -InstallOptDistr $InstallOptDistr -ProductVer $HighPlatform -LogFile $LogFile
            }
        }

        # ������ ��� ������������� ������ ����� �������, ���� ��� ���������
        # ����� ����� �� ���� ������� ��������� ������� ����� �� ������� �������, �� ���� ������ ��� �������� ��� ���������
        If ($DeletPar -match "^ael$") {
            ForEach ($Platform in $NeedUninstallPlatforms) {
                If ( -not ( ($Platform.Version -match $HighPlatform) -or ($Platform.Version -match $InstallPar) ) ) {
                    UninstallPlatform -Product $Platform -LogFile $LogFile
                }
            }
        }
    }
}

# ��������� �������� ���� ���� ������ ������� ���������� ������, �������� ����� �����������, ������� ���� ��������� ��� ������ ������ �� ���� ������ ��� ���������
If ($DeletPar -match $RegExpPatternNumPlatform) {
    If (($InstallPar -match '^last$') -and ($CountPlatform -ne 0)) {
        If ($DeletPar -eq $HighPlatform) {
            WriteLog $LogFile "��������� 1� ������ $DeletPar �� ����� �������, �.�. ��� ��������� �������."
        }
    } elseif ($InstallPar -eq $DeletPar) {
        WriteLog $LogFile "����� dl � di ���������. �������� ������������� �� �����"
    } else {
        $FlagPlatformInstall = $false
        ForEach ($PlatformOnComputer in $InstallPlatformsOnComputer) {
            If ($PlatformOnComputer.Version -match $DeletPar) {
                $FlagPlatformInstall = $true 
                $NeedUninstallPlatform = $PlatformOnComputer       
            }
        }
        If ($FlagPlatformInstall) {
            UninstallPlatform -Product $NeedUninstallPlatform -LogFile $LogFile    
        } else {
            WriteLog $LogFile "��������� 1� ������ $DeletPar �� �����������. ������� ������"
        }
    }
}

EndLogFile -LogFile $LogFile
