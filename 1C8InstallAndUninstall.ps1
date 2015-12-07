# зададим параметры по умолчанию. Данные параметры можно поменять передав их скрипту перед выполнением
param([string]$dd = "\\Server\1CDistr", # путь до каталога с дистрибутивами платфоры 1С 8
      [string]$dl = "\\Server\1СLogs", # путь до каталога в который будут записываться логи установки и удаления
      [string]$ip = "last", # параметры инсталяции согласно которым будет работать скрипт
      [string]$dp = "ael", # параметры удаления соответствии с которыми будет работать скрипт
      [string]$iod = "DESIGNERALLCLIENTS=1 THINCLIENT=1 THINCLIENTFILE=1") # параметры задаваемые при установке самой платформы

# Преобразуем все переменные к более читабельному виду
$DistribDir = $dd
$DirLog = $dl
$InstallPar = $ip
$DeletPar = $dp
$InstallOptDistr = $iod

# Вспомогательные параметры
$RegExpPatternNameFolderDistrib = "^(\d+\.\d+)\.(\d+\.\d+)$"

#======================================================================================
#======================================================================================
#================ Начало Функций ======================================================

# Функция служит для записи и поддержания однообразия записей в файле логировния
# Входящие данные: Путь до файла логирования и строка которую надо в него записать
# Возвращяемые параметры: нет
Function WriteLog($LogFile, $str) {
    ((Get-Date -UFormat "%Y.%m.%d %T") + " " + $str) >> $LogFile
}

# Благодоря данной функции окончание файла логирования всегода одинаковое
# Входящие данные: Путь до файла логирования
# Возвращяемые параметры: нет
Function EndLogFile($LogFile) {    WriteLog $LogFile "Окончание работы скрипта"     "---------------------------------------------------------------------------------" >> $LogFile     Exit}

# Данная функция вызывается в случае невозможности записи лог файлов в указанный для этого каталог
# Входящие данные: нет
# Возвращяемые параметры: прямой путь до лог файла
Function ErrDirLog {
    $LogFile = $env:LOCALAPPDATA + "\1C8InstallAndUninstall.log"    # проверим существование файла для логирования в указанном пути
    If (-not (Test-Path -path $LogFile)) {
        # файл не существует, создадим его
        $LogFile = New-Item -Path $LogFile -ItemType "file"    }
    Return $LogFile}

# функция находит все установленные программы 1С:Предприятия 8 на компьютере
# Входящие данные: нет
# Возвращяемые параметры: массив
Function SearchInstallPlatformsOnComputer {
    Return Get-WmiObject Win32_Product | Where-Object {$_.Name -match "^(1С|1C)"}   
}

# Функция проверяет наличие платформы на компьютере
# Входящие данные: массив уже установленных платформ, искомая платформа, 
# Возвращяемые параметры: булевое значение
Function PlatformInstallOnComputer ($AllInstallPlatformOnComputer, $SearchPlatform) {
    $FlagPlatformInstall = $false    ForEach ($PlatformOnComputer in $AllInstallPlatformOnComputer) {
        If ($PlatformOnComputer.Version -match $SearchPlatform) {
            $FlagPlatformInstall = $true        
        }
    }
    Return $FlagPlatformInstall   
}

# непосредстенное удаление 1С:Предприятие с компьютера
# Входящие данные: код продукта или путь до каталога с удаляемой версией, версия продукта, путь к файлу с логами
# Возвращяемые параметры: нет
Function UninstallPlatform ($Product, $ProductVer, $LogFile) {
    WriteLog $LogFile ("Удаление 1С:Предприятие, версия " + $ProductVer)    
    # проверим что пришло в переменную $Product
    If ( -not ($Product -match "^{.*}$")) {
        # в переменную пришол путь к папке с дистрибутивом удаляемого продукта, преобразуем его
        # приведём полученные пути к каталогу установки к нужной форме добавив в них обратный слеш в конце
        If (-not $Product.EndsWith("\")) {$Product = $Product + "\"}
          
        # проверим соответствие переданой версии и версии находящейся в папке с установкой
        $SetupFile = Get-Content ($Product + "setup.ini")
        [string]$SetupFile -match "ProductVersion=(?<ver>$RegExpPatternNameFolderDistrib)"
        If ( -not ($ProductVer -match $matches.ver) ) {
            WriteLog $LogFile ("Внимание. Должна быть удалена версия " + $ProductVer + ", но в каталоге находиться версия " + $matches.ver + ", именно она будет удалена")
        }

        # Найдём msi файл удаляемого продукта        $MSIfile = "....."        $MSIfile = (Get-ChildItem -Path $Product | Where-Object {$_.Name -match "^(1C|1С).*\.msi$"}).Name        $MSIfile = $Product + $MSIfile                # Проверим найденный путь        If (-not (Test-Path -Path $MSIfile) ) {            WriteLog $LogFile ("Не найден msi файл в каталоге " + $Product + " удаление невозможно")            Return 0        }                # msi файл найден, переопределим переменную $Product для унификации команды удаления        $Product = $MSIfile    }

    Start-Process -Wait -FilePath msiexec -ArgumentList  ('/uninstall "' + $Product + '" /quiet /norestart /Leo+ "' + $LogFile + '"')
}

# непосредстенное установка 1С:Предприятие на компьютер
# Входящие данные: полный путь до папки с платформой, опции установки, версия устанавливаемого продукта, путь к файлу с логами
# Возвращяемые параметры: нет
Function InstallPlatform ($InstallFolder, $InstallOptDistr, $ProductVer, $LogFile){
    WriteLog $LogFile ("Установка 1С:Предприятие, версия " + $ProductVer)    
    # приведём полученные пути к каталогу установки к нужной форме добавив в них обратный слеш в конце
    If (-not $InstallFolder.EndsWith("\")) {$InstallFolder = $InstallFolder + "\"}

    # проверим соответствие переданой версии и версии находящейся в папке с установкой
    $SetupFile = Get-Content ($InstallFolder + "setup.ini")
    [string]$SetupFile -match "ProductVersion=(?<ver>$RegExpPatternNameFolderDistrib)"
    If ( -not ($ProductVer -match $matches.ver) ) {
            WriteLog $LogFile ("Внимание. Должна быть установлена версия " + $ProductVer + ", но в каталоге находиться версия " + $matches.ver + ", именно она будет установлена")
    }

    # Найдём установочный msi файл    $InstallMSI = "....."    $InstallMSI = (Get-ChildItem -Path $InstallFolder | Where-Object {$_.Name -match "^(1C|1С).*\.msi$"}).Name    $InstallMSI = $InstallFolder + $InstallMSI    # Проверим найденный путь    If (-not (Test-Path -Path $InstallMSI) ) {        WriteLog $LogFile ("Не найден установочный msi файл в каталоге " + $InstallFolder + " установка прекращена")        Return 0    }    # Поищим файлы ответов    If ( (Test-Path -Path ($InstallFolder + 'adminstallrestart.mst')) -and (Test-Path -Path ($InstallFolder + '1049.mst')) ) {        # файлы ответов найдены, подготовим инсталятор        Start-Process -Wait -FilePath  msiexec -ArgumentList ('/jm "' + $InstallMSI + '" /t adminstallrestart.mst;1049.mst /quiet /norestart /Leo+ "' + $LogFile + '"')    } else {        # файлы ответов не найдены, сообщим это и не будем подготавливать инсталятор        WriteLog $LogFile ("Не найден файл ответов adminstallrestart.mst или 1049.mst в каталоге " + $InstallFolder + " установка будет произведена без подготовки")    }

    # проверим опции установки, если они не соответствуют шаблону, то включим установку всех компонентов    If ( -not ($InstallOptDistr -match "DESIGNERALLCLIENTS=(0|1) THINCLIENT=(0|1) THINCLIENTFILE=(0|1)") ) {        WriteLog $LogFile ("Переданный скрипту параметр '-iod' имеет значение " + $InstallOptDistr + " это недопустимо. Будут установлены все клиентские компаненты платформы.")        $InstallOptDistr = "DESIGNERALLCLIENTS=1 THINCLIENT=1 THINCLIENTFILE=1"    }             # произведём непосредственную установку    Start-Process -Wait -FilePath msiexec -ArgumentList ('/package "' + $InstallMSI + '" ' + $InstallOptDistr + ' /quiet /norestart /Leo+ "' + $LogFile + '"')    }

#================= Конец Функций ======================================================
#======================================================================================
#======================================================================================

# приведём полученные пути к каталогам к нужной форме добавив в них обратный слеш в конце
If (-not $DistribDir.EndsWith("\")) {$DistribDir = $DistribDir + "\"}
If (-not $DirLog.EndsWith("\")) {$DirLog = $DirLog + "\"}

# для каждого из компьютеров будет свой лог файл соответствующий имени компьютера. в одной сети не может быть 2 компьютера с одинаковыми именами
$LogFile = $DirLog + $env:COMPUTERNAME + ".log"
# создадим вспомогательную переменную с описанием ошибки
$StrErr = ""

# проверим существование файла для логирования в указанном пути
If (Test-Path -path $LogFile) {
    # файл существует, попробум в него записать
    Try {
        Out-File -FilePath $LogFile -InputObject "" -Append -ErrorAction Stop
    } Catch {
        # опишем ошибку
        $StrErr = "Не удалось записать логи в $LogFile"        # меняем путь к файлу логирования
        $LogFile = ErrDirLog
    }} else {
    # файл НЕ существует, попытаемся создадать его
    Try {
        $LogFile = New-Item -Path $LogFile -ItemType "file" -ErrorAction Stop
    } Catch {
        # опишем ошибку
        $StrErr = "Не удалось создать файл $LogFile"        # создать файл в каталоге указанный для скрипта не удалось, меняем путь к файлу логирования
        $LogFile = ErrDirLog
    }}

# запишем данные о начале работы скрипта
" " >> $LogFile
"---------------------------------------------------------------------------------" >> $LogFile"Параметры запуска скрипта: -dd '$dd' -dl '$dl' -dp '$dp' -ip '$ip' -iod '$iod'" >> $LogFileWriteLog $LogFile "Начало работы скрипта"If ($StrErr.Length -ne 0) {WriteLog $LogFile $StrErr}        
# Проверим необходимость дальнейших действий. Параметры установки и удаления находятся в положении "no"?If ($InstallPar -match "no" -and $DeletPar -match "no") {    WriteLog $LogFile "Параметры установки и удаления находяться в положении 'no', ни каких действий выполнять не требуется."
    EndLogFile -LogFile $LogFile
}# проверим адекватность значений переданныз в параметры# Проверим значения для инсталяцииIf ( -not (  ($InstallPar -match "no") -or ($InstallPar -match "last") -or ($InstallPar -match $RegExpPatternNameFolderDistrib) ) ) {
    WriteLog $LogFile "Значения параметра инсталяции не подходит не под один из известных, установка производиться не будет."}# Проверим значения для удаленияIf ( -not ( ($DeletPar -match "no") -or ($DeletPar -match "ael") -or ($DeletPar -match $RegExpPatternNameFolderDistrib) -or ($DeletPar -match "all") ) ) {
    WriteLog $LogFile "Значения параметра удаления не подходит не под один из известных, удаление производиться не будет."}
# найдём все установленные платформы 1С на компьютере
# достаточно длительная операция. если появится возможность её ускорить или убрать, то сообщите
$InstallPlatformsOnComputer = SearchInstallPlatformsOnComputer

# отработаем исключителюную операцию удаления всех дистрибутивов если в скрипт передали параметр -dp "all"
If ($DeletPar -match "all") {
    WriteLog $LogFile "Параметр удаления находяться в положении 'all', все остальные параметры игнорируются и производиться удаление всех найденных на компьютере платформ."
    # Последовательно удалим все платформы
    ForEach ($PlatformOnComputer in $InstallPlatformsOnComputer) {
        UninstallPlatform -Product $PlatformOnComputer.IdentifyingNumber -ProductVer $PlatformOnComputer.Version -LogFile $LogFile    
    }
    EndLogFile -LogFile $LogFile
}

# После всех проверок выше можно заключить что имеется хотябы один из параметров "x.x.x.x" или "last" или "ael" 
#  прверим доступ к каталогу с дистрибутивами, как указано выше, для выполнения одного из параметров нам понадобиться доступ к каталогу с дистрибутивами
If (-not (Test-Path -path $DistribDir)) {
    # доступ к каталогу с дистрибутивами 1С закрыт или не существует, запишем это и выйдем из скрипта
    WriteLog $LogFile "Не удалось получить доступ к каталогу с дистрибутивами 1С, проверьте путь и права доступа $DistribDir"
    EndLogFile -LogFile $LogFile
}# произведём установку если было заданано установить конкретную версию, но перед этим проверим что данная версия не установлена на компьютерIf ($InstallPar -match $RegExpPatternNameFolderDistrib) {    If (PlatformInstallOnComputer $InstallPlatformsOnComputer $InstallPar) {
        WriteLog $LogFile "Платформа 1С версии $InstallPar уже установлена"
    } else {
    # надо проверить существование пути до устанавливаемой платформы
        If (Test-Path -path ($DistribDir + $InstallPar)) {
            InstallPlatform -InstallFolder ($DistribDir + $InstallPar) -InstallOptDistr $InstallOptDistr -ProductVer $InstallPar -LogFile $LogFile
        } else {
            WriteLog $LogFile "Не существует каталога $DistribDir$InstallPar. Установка произведена не будет"
        }
    }
}
# Проверим имееются ли параметры "last" или "eal"If ( ($InstallPar -match "last") -or ($DeletPar -match "ael") ) {    # вспомогательные переменные    If ($DeletPar -match "ael") {         [array]$NeedUninstallPlatforms = @()
    }    $CountPlatform = 0    $MaxNumMajor = 0    $MaxNumMinor = 0    # пройдёмся по папке с дистрибутивами и найдём старшую из версий, а так же создадим массив платформ которые должны быть удалены    ForEach ($Element in (Get-ChildItem -Path $DistribDir)) {        If (($Element.Mode -match "d*") -and ($Element.Name -match $RegExpPatternNameFolderDistrib)) {                    $CountPlatform = $CountPlatform + 1            # найдём старшую платформу            If ([double]$Matches[1] -eq $MaxNumMajor) {                If ([double]$Matches[2] -ge $MaxNumMinor) {                    $HighPlatform = $Element.Name                    $MaxNumMinor = [double]$Matches[2]                }            }            If ([double]$Matches[1] -gt $MaxNumMajor) {                $HighPlatform = $Element.Name                $MaxNumMajor = [double]$Matches[1]                $MaxNumMinor = [double]$Matches[2]            }            # пометим платформу на удаление, если она совпадает с установленной на компьютере            If ($DeletPar -match "ael") {                 ForEach ($PlatformOnComputer in $InstallPlatformsOnComputer) {                    If ($Element.Name -eq $PlatformOnComputer.Version) {                        $NeedUninstallPlatforms = $NeedUninstallPlatforms + $Element.Name                     }                }            }        }    }        # посмотрим на кол-во найденых дистрибутивов    If ($CountPlatform -eq 0) {        WriteLog $LogFile "Не найдено не одного дистрибутива 1С Предприятия в $DistribDir установка с ключом -ip 'last' или удаление с ключом -dp 'ael' не будут производиться."
    } elseif ($CountPlatform -eq 1) {
        If ($InstallPar -match 'last' ) {
            # проверим не установлен ли старший дистрибутив, чтобы избежать повторной установки
            If (PlatformInstallOnComputer $InstallPlatformsOnComputer $HighPlatform) {
                WriteLog $LogFile "Найден только один дистрибудит $HighPlatform, но он уже установлен, повторная установка производиться не будет."
            } else {            
                InstallPlatform -InstallFolder ($DistribDir + $HighPlatform) -InstallOptDistr $InstallOptDistr -ProductVer $HighPlatform -LogFile $LogFile
            }
        }
        If ($DeletPar -match 'ael') {
            WriteLog $LogFile "Найден только один дитрибутив $HighPlatform. Удаление произведено не будет, т.к. данный дистрибутив является последним (старшим)."
        }
    } else {

        # установим старшую версию, если это требуется        If ($InstallPar -match 'last') {            # проверим, не установлена ли уже данная версия на компьютере            If (PlatformInstallOnComputer $InstallPlatformsOnComputer $HighPlatform) {
                WriteLog $LogFile "Последняя (старшая) платформа $HighPlatform уже установлена."
            } else {            
                InstallPlatform -InstallFolder ($DistribDir + $HighPlatform) -InstallOptDistr $InstallOptDistr -ProductVer $HighPlatform -LogFile $LogFile
            }
        }        # удалим все установленные версии кроме старшей если это требуется        If ($DeletPar -match "ael") {            ForEach ($Platform in $NeedUninstallPlatforms) {
                If ( -not ($Platform -match $HighPlatform) ) {
                    UninstallPlatform -Product ($DistribDir + $Platform) -ProductVer $Platform -LogFile $LogFile
                }
            }
        }
    }}# произведём удаление если было задано удалить конкретную версию, удаление менее приоритетно, поэтому надо убедиться что данная версия не была задана для установкиIf ($DeletPar -match $RegExpPatternNameFolderDistrib) {    If (($InstallPar -match 'last') -and ($CountPlatform -ne 0)) {        If ($DeletPar -eq $HighPlatform) {            WriteLog $LogFile "Платформа 1С версии $DeletPar не будет удалена, т.к. она считается старшей."
        }    } elseif ($InstallPar -eq $DeletPar) {        WriteLog $LogFile "Ключи dl и di совпадают. Удаление производиться не будет"
    } else {        $FlagPlatformInstall = $false        ForEach ($PlatformOnComputer in $InstallPlatformsOnComputer) {
            If ($PlatformOnComputer.Version -match $DeletPar) {
                $FlagPlatformInstall = $true 
                $NeedUninstallPlatform = $PlatformOnComputer       
            }
        }
        If ($FlagPlatformInstall) {
            UninstallPlatform -Product $NeedUninstallPlatform.IdentifyingNumber -ProductVer $NeedUninstallPlatform.Version -LogFile $LogFile    
        } else {
            WriteLog $LogFile "Платформа 1С версии $DeletPar не установлена. Удалять нечего"
        }
    }
}
EndLogFile -LogFile $LogFile
