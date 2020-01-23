# Описание: Скрипт позволяет устанавливать и удалять платформу 1С
# Автор: Dim
# Версия: 1.04
# зададим параметры по умолчанию. Данные параметры можно поменять передав их скрипту перед выполнением
param([string]$dd = "\\1CServer\1CDistr", # путь до каталога с дистрибутивами платфоры 1С 8
      [string]$dl = "\\1CServer\1CLogs", # путь до каталога в который будут записываться логи установки и удаления
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
$RegExpPatternNumPlatform = "^(\d+\.\d+)\.(\d+\.\d+)$"
$RegExpPatternNameFolderDistrib = "^(\d+\.\d+)\.(\d+\.\d+)(|-32|-64)$"

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
Function EndLogFile($LogFile) {
    WriteLog $LogFile "Окончание работы скрипта" 
    "---------------------------------------------------------------------------------" >> $LogFile 
    Exit
}

# Данная функция вызывается в случае невозможности записи лог файлов в указанный для этого каталог
# Входящие данные: нет
# Возвращяемые параметры: прямой путь до лог файла
Function ErrDirLog {
    $LogFile = $env:LOCALAPPDATA + "\1C8InstallAndUninstall.log"
    # проверим существование файла для логирования в указанном пути
    If (-not (Test-Path -path $LogFile)) {
        # файл не существует, создадим его
        $LogFile = New-Item -Path $LogFile -ItemType "file"
    }
    Return $LogFile
}

# функция находит все установленные программы 1С:Предприятия 8 на компьютере
# Входящие данные: нет
# Возвращяемые параметры: массив
Function SearchInstallPlatformsOnComputer {
    Return Get-WmiObject Win32_Product | Where-Object {$_.Name -match "^(1С|1C)"}   
}

# Функция проверяет наличие платформы на компьютере
# Входящие данные: массив уже установленных платформ, искомая платформа
# Возвращяемые параметры: булевое значение
Function PlatformInstallOnComputer ($AllInstallPlatformOnComputer, $SearchPlatform) {
    $FlagPlatformInstall = $false
    ForEach ($PlatformOnComputer in $AllInstallPlatformOnComputer) {
        If ($PlatformOnComputer.Version -match $SearchPlatform) {
            $FlagPlatformInstall = $true        
        }
    }
    Return $FlagPlatformInstall   
}

# непосредстенное удаление 1С:Предприятие с компьютера
# Входящие данные: код продукта, версия продукта, путь к файлу с логами
# Возвращяемые параметры: нет
Function UninstallPlatform ($Product, $LogFile) {
    $IdentifyingNumber = $Product.IdentifyingNumber
    $Version = $Product.Version
    WriteLog $LogFile ("Удаление 1С:Предприятие, версия " + $Version)

    Start-Process -Wait -FilePath msiexec -ArgumentList  ('/uninstall "' + $IdentifyingNumber + '" /quiet /norestart /Leo+ "' + $LogFile + '"')
}

# непосредстенное установка 1С:Предприятие на компьютер
# Входящие данные: путь до папки с платформами, опции установки, версия устанавливаемого продукта, путь к файлу с логами
# Возвращяемые параметры: нет
Function InstallPlatform ($DistribDir, $InstallOptDistr, $ProductVer, $LogFile){
    WriteLog $LogFile ("Установка 1С:Предприятие, версия " + $ProductVer)

    # данный флаг попожет определить была ли произведена попытка установки, нужен в конце скрипта
    $FlagAttemptInstall = $false
      
    # посмотрим на битность системы
    If ( (Get-WmiObject Win32_OperatingSystem).OSArchitecture -match "32") {
        $OSArch = "32"
    } else {
        $OSArch = "64"
    }
    
    # составим специальный массив в который запишим пути до возможных видов папок в зависимости от разрядности системы
    If ($OSArch -match "32") {
        $InstallFolders = @( ($DistribDir + $ProductVer + "-32\") , ($DistribDir + $ProductVer + "\") )
    } else {
        $InstallFolders = @( ($DistribDir + $ProductVer + "-64\"), ($DistribDir + $ProductVer + "\") )
    }

    ForEach ($InstallFolder in $InstallFolders) {
        # Проверим существование данной папки, ранее мы только сделали предположение о существовании папок
        If ( -not (Test-Path -Path $InstallFolder) ) {
            Continue
        }
        
        # Проверим не была ли осуществлена попытка установки скрипта ранее
        If ( $FlagAttemptInstall ) {
            Continue
        }
            
        # Найдём установочный msi файл
        $InstallMSI = "....."
        $InstallMSI = (Get-ChildItem -Path $InstallFolder | Where-Object {$_.Name -match "^(1CEnterprise 8 \(x86-64\)|1CEnterprise 8)\.msi$"}).Name
        If ($InstallMSI -match "^$") {
            WriteLog $LogFile ('Не найден установочный msi файл в каталоге "' + $InstallFolder + '". Установка платформы из данного каталога невозможна.')
            Continue
        }        
        $InstallMSI = $InstallFolder + $InstallMSI
        
        # Проверим найденный путь
        If (-not (Test-Path -Path $InstallMSI) ) {
            WriteLog $LogFile ('При поиски файла msi произошла ошибка. Установка платформы из данного каталога невозможна.')
            Continue
        }

        # проверим соответствие переданой версии и версии находящейся в папке с установкой
        $PathSetupFile = $InstallFolder + "setup.ini"
        If (-not (Test-Path -Path $PathSetupFile) ) {
            WriteLog $LogFile ('Не найден файл setup.ini в каталоге "' + $InstallFolder + '". Установка платформы из данного каталога невозможна.')
            Continue
        }

        # получим данные из файла setup.ini
        $SetupFile = Get-Content $PathSetupFile
        # проверим какая версия указана в файле setup.ini
        If ( -not ( ([string]$SetupFile).Contains("ProductVersion=$ProductVer") ) ) {
            WriteLog $LogFile ('Должна быть установлена версия ' + $ProductVer + ', но в каталоге "' + $InstallFolder + '" находиться версия другая версия платформы. Установка платформы из данного каталога прервана.')
            Continue
        }

        # Проверим версию платформы и версию операционной системы, т.к. невозможно установить 64 битную верси платформы на 32 битную версию системы
        If ( ( $OSArch -match "32" ) -and ( ([string]$SetupFile).Contains("Product=1C:Enterprise 8 (x86-64)" -or ([string]$SetupFile).Contains("Product=1C:Enterprise 8 Thin client (x86-64)") ) ) ) {
            WriteLog $LogFile ('В каталоге "' + $InstallFolder + '" находиться 64-бинтая версия платформы, невозможно установить 64-битную версию платформы на 32-битную систему')
            Continue
        }
        
        # проверим опции установки, если они не соответствуют шаблону, то включим установку всех компонентов
        If ( -not ($InstallOptDistr -match "DESIGNERALLCLIENTS=(0|1) THINCLIENT=(0|1) THINCLIENTFILE=(0|1)") ) {
            WriteLog $LogFile ('Переданный скрипту параметр "-iod" имеет не допустимое значение "' + $InstallOptDistr + '". Будут установлены все клиентские компоненты платформы.')
            $InstallOptDistr = "DESIGNERALLCLIENTS=1 THINCLIENT=1 THINCLIENTFILE=1"
        }    
     
        # произведём установку Visual C++ Redistributable
        $vc_redist = "....."
        $vc_redist = (Get-ChildItem -Path $InstallFolder | Where-Object {$_.Name -match "^vc_redist.*.exe$"}).Name
        If ($vc_redist -match "^$") {
            WriteLog $LogFile ('Не найден файл для Visual C++ Redistributable в каталоге "' + $InstallFolder + '". Установка платформы продолжится.')
        } else {        
            $vc_redist = $InstallFolder + $vc_redist
            # Проверим найденный путь
            If (-not (Test-Path -Path $vc_redist) ) {
                WriteLog $LogFile ('При поиски файла для Visual C++ Redistributable произошла ошибка. Установка платформы продолжится.')                
            }  else {
            Start-Process -Wait -FilePath $vc_redist -ArgumentList ('/install /quiet /norestart')
            }
        }        

        # Поищем файлы ответов
        If ( (Test-Path -Path ($InstallFolder + 'adminstallrestart.mst')) -and (Test-Path -Path ($InstallFolder + '1049.mst')) ) {
            # файлы ответов найдены, подготовим инсталятор
            Start-Process -Wait -FilePath  msiexec -ArgumentList ('/jm "' + $InstallMSI + '" /t adminstallrestart.mst;1049.mst /quiet /norestart /Leo+ "' + $LogFile + '"')
        } else {
            # файлы ответов не найдены, сообщим это и не будем подготавливать инсталятор
            WriteLog $LogFile ('Не найден файл ответов adminstallrestart.mst или 1049.mst в каталоге "' + $InstallFolder + '" установка будет произведена без подготовки')
        }
        
        # произведём непосредственную установку
        Start-Process -Wait -FilePath msiexec -ArgumentList ('/package "' + $InstallMSI + '" ' + $InstallOptDistr + ' /quiet /norestart /Leo+ "' + $LogFile + '"')    
        $FlagAttemptInstall = $true
    }
    
    # сообщим что установка из других каталогов для системы не производится, если не было попыток установки
    If ( (-not $FlagAttemptInstall) -and (Test-Path ($DistribDir + $ProductVer + "-32\") ) -and ($OSArch = "64") ) {
        WriteLog $LogFile 'Для 64-битной системы не производится установка из каталога преднозначенного для 32-битной системы'
    }
    If ( (-not $FlagAttemptInstall) -and (Test-Path ($DistribDir + $ProductVer + "-64\") ) -and ($OSArch = "32") ) {
        WriteLog $LogFile 'Для 32-битной системы не производится установка из каталога преднозначенного для 64-битной системы'
    }

    # проверим установилась ли необходимая нам платформа
    $NewInstallPlatformsOnComputer = SearchInstallPlatformsOnComputer
    If ( -not (PlatformInstallOnComputer $NewInstallPlatformsOnComputer $ProductVer)) {
        WriteLog $LogFile "После установки не была найдена платформа $ProductVer на данном компьютере. Работа скрипта прервана."
        EndLogFile $LogFile
    }
}

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
        $StrErr = "Не удалось записать логи в $LogFile"
        # меняем путь к файлу логирования
        $LogFile = ErrDirLog
    }
} else {
    # файл НЕ существует, попытаемся создадать его
    Try {
        $LogFile = New-Item -Path $LogFile -ItemType "file" -ErrorAction Stop
    } Catch {
        # опишем ошибку
        $StrErr = "Не удалось создать файл $LogFile"
        # создать файл в каталоге указанный для скрипта не удалось, меняем путь к файлу логирования
        $LogFile = ErrDirLog
    }
}

# запишем данные о начале работы скрипта
" " >> $LogFile
"---------------------------------------------------------------------------------" >> $LogFile
"Параметры запуска скрипта: -dd '$dd' -dl '$dl' -dp '$dp' -ip '$ip' -iod '$iod'" >> $LogFile

WriteLog $LogFile "Начало работы скрипта"
If ($StrErr.Length -ne 0) {WriteLog $LogFile $StrErr}    
    
# Проверим необходимость дальнейших действий. Параметры установки и удаления находятся в положении "no"?
If ($InstallPar -match "^no$" -and $DeletPar -match "^no$") {
    WriteLog $LogFile 'Параметры установки и удаления находяться в положении "no", ни каких действий выполнять не требуется.'
    EndLogFile -LogFile $LogFile
}

# Проверим значения для инсталяции
If ( -not (  ($InstallPar -match "^no$") -or ($InstallPar -match "^last$") -or ($InstallPar -match $RegExpPatternNumPlatform) ) ) {
    WriteLog $LogFile "Значения параметра инсталяции не подходит не под один из известных. Работа скрипта прервана."
    EndLogFile -LogFile $LogFile
}

$InstallPlatformsOnComputer = SearchInstallPlatformsOnComputer

# отработаем исключителюную операцию удаления всех дистрибутивов если в скрипт передали параметр -dp "all"
If ($DeletPar -match "^all$") {
    WriteLog $LogFile 'Параметр удаления находяться в положении "all", все остальные параметры игнорируются и производиться удаление всех найденных на компьютере платформ 1С Предприятие.'
    # Последовательно удалим все платформы
    ForEach ($PlatformOnComputer in $InstallPlatformsOnComputer) {
        UninstallPlatform -Product $PlatformOnComputer -LogFile $LogFile
    }
    EndLogFile -LogFile $LogFile
}

# Проверим значения для удаления
If ( -not ( ($DeletPar -match "^no$") -or ($DeletPar -match "^ael$") -or ($DeletPar -match $RegExpPatternNumPlatform) -or ($DeletPar -match "^all$") ) ) {
    WriteLog $LogFile "Значения параметра удаления не подходит не под один из известных, удаление производиться не будет."
}

# После всех проверок выше можно заключить что имеется хотя бы один из параметров "x.x.x.x" или "last" или "ael"
# прверим доступ к каталогу с дистрибутивами, как указано выше, для выполнения одного из параметров нам понадобиться доступ к каталогу с дистрибутивами
If (-not (Test-Path -path $DistribDir)) {
    # доступ к каталогу с дистрибутивами 1С закрыт или не существует, запишем это и выйдем из скрипта
    WriteLog $LogFile "Не удалось получить доступ к каталогу с дистрибутивами 1С, проверьте путь и права доступа $DistribDir"
    EndLogFile -LogFile $LogFile
}

# найдём все установленные платформы 1С на компьютере
# достаточно длительная операция. если появится возможность её ускорить или убрать, то сообщите
$InstallPlatformsOnComputer = SearchInstallPlatformsOnComputer

# произведём установку если было заданано установить конкретную версию, но перед этим проверим что данная версия не установлена на компьютер
If ($InstallPar -match $RegExpPatternNumPlatform) {
    If (PlatformInstallOnComputer $InstallPlatformsOnComputer $InstallPar) {
        WriteLog $LogFile "Платформа 1С версии $InstallPar уже установлена"
    } else {    
        InstallPlatform -DistribDir $DistribDir -InstallOptDistr $InstallOptDistr -ProductVer $InstallPar -LogFile $LogFile
    }
}

# Проверим имееются ли параметры "last" или "eal"
If ( ($InstallPar -match "^last$") -or ($DeletPar -match "^ael$") ) {

    # вспомогательные переменные
    If ($DeletPar -match "^ael$") { 
        [array]$NeedUninstallPlatforms = @()
    }
    $CountPlatform = 0
    $MaxNumMajor = 0
    $MaxNumMinor = 0

    # пройдёмся по папке с дистрибутивами и найдём старшую из версий, а так же создадим массив платформ которые должны быть удалены
    ForEach ($Element in (Get-ChildItem -Path $DistribDir)) {
        If (($Element.Mode -match "d*") -and ($Element.Name -match $RegExpPatternNameFolderDistrib)) {        
            $CountPlatform = $CountPlatform + 1
            # найдём старшую платформу
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
            # пометим платформу на удаление, если она совпадает с установленной на компьютере
            If ($DeletPar -match "^ael$") { 
                ForEach ($PlatformOnComputer in $InstallPlatformsOnComputer) {
                    If ($Element.Name -eq $PlatformOnComputer.Version) {
                        $NeedUninstallPlatforms = $NeedUninstallPlatforms + $PlatformOnComputer 
                    }

                }
            }
        }
    }
    
    # посмотрим на кол-во найденых дистрибутивов
    If ($CountPlatform -eq 0) {
        WriteLog $LogFile "Не найдено не одного дистрибутива 1С Предприятия в $DistribDir установка с ключом -ip 'last' или удаление с ключом -dp 'ael' не будут производиться."
    } elseif ($CountPlatform -eq 1) {
        If ($InstallPar -match '^last$' ) {
            # проверим не установлен ли старший дистрибутив, чтобы избежать повторной установки
            If (PlatformInstallOnComputer $InstallPlatformsOnComputer $HighPlatform) {
                WriteLog $LogFile "Найден только один дистрибудит $HighPlatform, но он уже установлен, повторная установка производиться не будет."
            } else {            
                InstallPlatform -DistribDir $DistribDir -InstallOptDistr $InstallOptDistr -ProductVer $HighPlatform -LogFile $LogFile
            }
        }
        If ($DeletPar -match '^ael$') {
            WriteLog $LogFile "Найден только один дитрибутив $HighPlatform. Удаление произведено не будет, т.к. данный дистрибутив является последним (старшим)."
        }
    } else {
        # установим старшую версию, если это требуется
        If ($InstallPar -match '^last$') {
            # проверим, не установлена ли уже данная версия на компьютере
            If (PlatformInstallOnComputer $InstallPlatformsOnComputer $HighPlatform) {
                WriteLog $LogFile "Последняя (старшая) платформа $HighPlatform уже установлена."
            } else {            
                InstallPlatform -DistribDir $DistribDir -InstallOptDistr $InstallOptDistr -ProductVer $HighPlatform -LogFile $LogFile
            }
        }

        # удалим все установленные версии кроме старшей, если это требуется
        # важно чтобы не было удалена платформа которая может не являтся старшей, но была задана как параметр для установки
        If ($DeletPar -match "^ael$") {
            ForEach ($Platform in $NeedUninstallPlatforms) {
                If ( -not ( ($Platform.Version -match $HighPlatform) -or ($Platform.Version -match $InstallPar) ) ) {
                    UninstallPlatform -Product $Platform -LogFile $LogFile
                }
            }
        }
    }
}

# произведём удаление если было задано удалить конкретную версию, удаление менее приоритетно, поэтому надо убедиться что данная версия не была задана для установки
If ($DeletPar -match $RegExpPatternNumPlatform) {
    If (($InstallPar -match '^last$') -and ($CountPlatform -ne 0)) {
        If ($DeletPar -eq $HighPlatform) {
            WriteLog $LogFile "Платформа 1С версии $DeletPar не будет удалена, т.к. она считается старшей."
        }
    } elseif ($InstallPar -eq $DeletPar) {
        WriteLog $LogFile "Ключи dl и di совпадают. Удаление производиться не будет"
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
            WriteLog $LogFile "Платформа 1С версии $DeletPar не установлена. Удалять нечего"
        }
    }
}

EndLogFile -LogFile $LogFile
