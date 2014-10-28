@rem для запуска powershell скриптов необходимо переопределить политику безопасности запуска powershell
	@start /wait powershell "Set-ExecutionPolicy RemoteSigned -Force"
@rem запускаем скрипт с нужными параметрами
	@powershell "\\Server\1CDistr\1C8InstallAndUninstall.ps1" -dd "\\Server\1CDistr" -dl "\\Server\1CLog" -dp ael -ip last
@rem возвращяем политику безопасности в значение по умолчанию
	@start /wait powershell "Set-ExecutionPolicy Restricted -Force"