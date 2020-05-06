@rem для запуска powershell скриптов необходимо переопределить политику безопасности запуска powershell
	@start /wait powershell "Set-ExecutionPolicy Bypass -Force"
@rem запускаем скрипт с нужными параметрами
	@powershell "\\Server\1CDistr\1C8InstallAndUninstall.ps1" -dd '\\Server\1CDistr' -dl '\\Server\1CLogs' -ip 'last' -dp 'ael' -iod 'DESIGNERALLCLIENTS=1 THINCLIENT=1 THINCLIENTFILE=1'
@rem возвращяем политику безопасности в значение по умолчанию
	@start /wait powershell "Set-ExecutionPolicy Restricted -Force"