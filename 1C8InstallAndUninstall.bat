@rem ��� ������� powershell �������� ���������� �������������� �������� ������������ ������� powershell
	@start /wait powershell "Set-ExecutionPolicy Bypass -Force"
@rem ��������� ������ � ������� �����������
	@powershell "\\Server\1CDistr\1C8InstallAndUninstall.ps1" -dd '\\Server\1CDistr' -dl '\\Server\1CLogs' -ip 'last' -dp 'ael' -iod 'DESIGNERALLCLIENTS=1 THINCLIENT=1 THINCLIENTFILE=1'
@rem ���������� �������� ������������ � �������� �� ���������
	@start /wait powershell "Set-ExecutionPolicy Restricted -Force"