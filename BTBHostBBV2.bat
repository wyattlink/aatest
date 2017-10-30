pushd %~dp0
set logs=c:\system.sav\logs\CEPS\BTBHost
set WizlogSpec=%logs%\wizinstaller.log
set asgMetroLogSpec=%logs%\asgmetro.log
set asgTaskbarLogSpec=%logs%\asgtaskbar.log
set logSpec=%logs%\%~nx0.log
set LayoutModificationXML=C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml
set TaskbarLayoutModificationXML=C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\TaskbarLayoutModification.xml
@echo %date% %time% BTB Post Install Start Running>> %WizlogSpec%

if exist C:\system.sav\util\SetVariables.cmd (Call c:\system.sav\util\SetVariables.cmd) else (echo [%date% %time%] SetVariables.cmd Not Found>>%logs%\%~nx0.log)
if exist C:\system.sav\util\TDCSetVariables.cmd (Call c:\system.sav\util\TDCSetVariables.cmd) else (echo [%date% %time%] TDCSetVariables.cmd Not Found>>%logs%\%~nx0.log)

md "C:\ProgramData\HP\Images"
if /I "%PCBRAND%" == "Presario" (
	copy "c:\hp\HPQWare\BTBHost\Images\cpq_wc_logo.png" "C:\ProgramData\HP\Images\wc_logo.png" /y
) else (
	copy "c:\hp\HPQWare\BTBHost\Images\hp_wc_logo.png" "C:\ProgramData\HP\Images\wc_logo.png" /y
)

if "%R_MIC%"=="1" (
	echo >> c:\system.sav\flags\BtBR_MIC.flg
	if exist c:\hp\bin\Rstone.ini (
		if exist c:\system.sav\flags\BtBOSWin10RS.flg (
			echo Copy MFU_cNB.ini for cNB RedStone MSSI >>%asgMetroLogSpec%
			copy /y %~dp0\Signature\RedStone\MFU_cNB.ini %~dp0\MFU.ini >>%asgMetroLogSpec% 2>&1
		) else (
			echo Copy MFU_cNB.ini for cNB MSSI >>%asgMetroLogSpec%
			copy /y %~dp0\Signature\MFU_cNB.ini %~dp0\MFU.ini >>%asgMetroLogSpec% 2>&1
		)
	) else (
		if exist c:\system.sav\flags\BtBOSWin10RS.flg (
			echo Copy MFU.ini for cPC RedStone MSSI >>%asgMetroLogSpec%
			copy /y %~dp0\Signature\RedStone\MFU.ini %~dp0\MFU.ini >>%asgMetroLogSpec% 2>&1
		) else (
			echo Copy MFU.ini for cPC MSSI >>%asgMetroLogSpec%
			copy /y %~dp0\Signature\MFU.ini %~dp0\MFU.ini >>%asgMetroLogSpec% 2>&1
		)
	)
)

:: Create the .reg files from the component metro.xml files
c:\hp\hpqware\btbhost\MetroXmlProcessor.exe c:\swsetup >> %asgMetroLogSpec%
echo. >>%asgMetroLogSpec%
if exist c:\system.sav\flags\BtBOSWin10.flg if NOT exist \system.sav\flags\BtBPinTileByReg.flg (
	if exist %LayoutModificationXML% c:\hp\hpqware\btbhost\RemoveXMLNS.vbs %LayoutModificationXML%
	copy /y %LayoutModificationXML% %logs%
)
:: Parse c:\hp\hpqware\btbhost\Taskbar.ini to create TaskbarLayoutModification.xml for RedStone taskbar app pinning
c:\hp\hpqware\btbhost\TaskbarProcessor.exe >> %asgTaskbarLogSpec%
echo. >>%asgTaskbarLogSpec%	
if exist c:\system.sav\flags\BtBOSWin10RS.flg if exist %TaskbarLayoutModificationXML% (
	echo delete c:\HP\HPQWare\BTBHost\PBR\RegSrc\Taskbar.ini >>%asgTaskbarLogSpec%
	del c:\HP\HPQWare\BTBHost\PBR\RegSrc\Taskbar.ini >>%asgTaskbarLogSpec% 2>&1
	reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer /v "LayoutXMLPath" /t REG_SZ /d %TaskbarLayoutModificationXML% /f >>%asgTaskbarLogSpec% 2>&1
	c:\hp\hpqware\btbhost\RemoveXMLNS.vbs %TaskbarLayoutModificationXML%
	copy /y %TaskbarLayoutModificationXML% %logs%
)

:: Win10 LayoutModification.xml solution doesn't need metro filler
if NOT exist \system.sav\flags\BtBPinTileByReg.flg goto NoFillerPresent
::Add filler tile if one is available and an odd number of tiles are present.
if NOT exist c:\hp\hpqware\metrofiller\metro.xml goto NoFillerPresent

pushd \hp\hpqware\metro\all\all
setlocal enabledelayedexpansion
set count=0

::metro.reg is unicode, metroTmp.reg will be ANSI so for /f will work.
more < metro.reg > metroTmp.reg

for /f %%a in ( metroTmp.reg ) do (
echo %%a | find /i "squaretiles\squaretile" >NUL && set /a count=!count!+1
)

set /a odd=!count!%% 2

if "%odd%"=="1" (
   if not exist c:\swsetup\metrofiller md c:\swsetup\metrofiller
   copy /y c:\hp\hpqware\metrofiller\metro.xml c:\swsetup\metrofiller
   del /f /q metro.reg
   del /f /q metroWinPE.reg
   c:\hp\hpqware\btbhost\metroxmlprocessor.exe c:\swsetup
)
del /f /q metroTmp.reg
rd /s/q c:\swsetup\metrofiller

endlocal
popd

:NoFillerPresent

echo.>>%asgMetroLogSpec%
c:\system.sav\util\WizInstaller.exe c:\hp\hpqware\btbhost\SCMID.ini >> %WizlogSpec%

:: Prep for 2pp setup
set postProcessDest=c:\system.sav\util\2postprocess
if NOT exist %postProcessDest% md %postProcessDest%

:: Set up 2pp so machine unique attributes are included in custom.data
echo==========%date% %time% BTB Post Install Start 2pp setup==========>>%logSpec%
set customDataDest=%postProcessDest%\customdata
if NOT exist %customDataDest% md %customDataDest% >>%logSpec% 2>&1
xcopy /y /f BtBCustomData.cmd %postProcessDest% >>%logSpec% 2>&1
xcopy /y /f customData.cmd %customDataDest% >>%logSpec% 2>&1
xcopy /y /f customData.ini %customDataDest% >>%logSpec% 2>&1
echo==========%date% %time% BTB Post Install End 2pp setup==========>>%logSpec%

:: check platform code
set cNB=0
echo [%date% %time%] PlatformCode=%PlatformCode%>>%logs%\%~nx0.log
if exist c:\hp\bin\Rstone.ini set cNB=1
if %cNB% == 1 (goto CNB) else (goto DEFAULT)

:CNB
::Import the tile registry
if exist \system.sav\flags\BtBPinTileByReg.flg (
   echo reg import C:\hp\HPQware\Metro\All\All\Metro.reg >>%asgMetroLogSpec%
   reg import C:\hp\HPQware\Metro\All\All\Metro.reg >>%asgMetroLogSpec% 2>&1
)
echo ====================%date% %time%  Setup PromoteOEMTiles Setting=================>>%logSpec%
set MSSIG=1
if exist c:\system.sav\flags\mssign.flg set MSSIG=0
if "%R_MIC%"=="1" set MSSIG=0

If "%MSSIG%"=="1" (
	echo adding OEM tile promotion to registry >>%asgMetroLogSpec%
	reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\SVDEn /v "PromoteOEMTiles" /t REG_DWORD /d 1 /f >>%asgMetroLogSpec% 2>&1
)

echo ====================%date% %time%  Finish Setup PromoteOEMTiles setting:%MSSIG%=================>>%logSpec%
goto :END


:DEFAULT

if NOT exist \system.sav\flags\BtBPinTileByReg.flg goto :END

:: Copy MetroWinPE.Reg for Win PE Import
set recImageLocation1=C:\system.sav\tweaks\Recovery\RecoveryImage\Point_D
set recImageLocation2=C:\system.sav\tweaks\Recovery\RecoveryImage\Point_B

if NOT exist %recImageLocation1% md %recImageLocation1%
if NOT exist %recImageLocation2% md %recImageLocation2%

copy /y C:\hp\hpqware\Metro\All\All\MetroWinPE.Reg %recImageLocation1%>> %asgMetroLogSpec% 2>&1
copy /y C:\hp\hpqware\Metro\All\All\MetroWinPE.Reg %recImageLocation2%>> %asgMetroLogSpec% 2>&1

:: Copy the import .cmd for Win PE import
copy /y PinTilesWPE.cmd %recImageLocation1%>> %asgMetroLogSpec% 2>&1
copy /y PinTilesWPE.cmd %recImageLocation2%>> %asgMetroLogSpec% 2>&1

::Set up tile 2pp, do not run now even if not GMPP
::copy /y PinTiles.cmd %postProcessDest% >> %asgMetroLogSpec% 2>&1
echo call PinTiles.cmd directly>>%logSpec%
call PinTiles.cmd
:END

echo==========%date% %time% Call BtBCustomData==========>>%logSpec%

:: If this is not GMPP build flow the unique attributes are available now
if NOT exist \system.sav\flags\GM2PP.FLG (
   echo GM2PP.FLG not presen, Call BtBCustomDatat>>%logSpec%
   pushd %postProcessDest%
   call BtBCustomData.cmd
   popd
)

:: Copy custom.data for HP Welcome that requested by Tracy 
echo==========%date% %time% Copy custom.data for HP Welcome==========>>%logSpec%
set customDataHPWelcome=C:\Program Files\HP\HP Welcome
if exist %customDataHPWelcome% (
   copy /y c:\Users\Default\Documents\hp.system.package.metadata\custom.hpdata "%customDataHPWelcome%\custom.data" >>%logSpec% 2>&1
)

:: Export registry for recovery
if exist c:\system.sav\flags\BtBOSWin10.flg if NOT exist \system.sav\flags\BtBPinTileByReg.flg (
	if exist c:\system.sav\flags\Disney.flg (
		echo do not restore taskbar in Crunch 1.1 SE >>%logSpec%
		del /f /q %~dp0\PBR\RegSrc\Taskbar.ini >> %logSpec% 2>&1
	)
	echo call %~dp0\PBR\ExportRegXML.cmd >>%logSpec%
	call %~dp0\PBR\ExportRegXML.cmd >>%logSpec%
	if exist C:\Recovery\OEM\Point_B\ (
		echo copy PBR command to C:\Recovery\OEM\Point_B\ >>%logSpec%
		copy /y %~dp0\PBR\BTBHostB_PBR.cmd C:\Recovery\OEM\Point_B\ >> %logSpec% 2>&1
		if exist %~dp0\PBR\BTBHost\ xcopy /e/i/y/f %~dp0\PBR\BTBHost\*.* C:\Recovery\OEM\Point_B\BTBHost\*.* >> %logSpec% 2>&1
	)
	if exist C:\Recovery\OEM\Point_D\ (
		echo copy PBR command to C:\Recovery\OEM\Point_D\ >>%logSpec%
		copy /y %~dp0\PBR\BTBHostD_PBR.cmd C:\Recovery\OEM\Point_D\ >> %logSpec% 2>&1
		if exist %~dp0\PBR\BTBHost\ xcopy /e/i/y/f %~dp0\PBR\BTBHost\*.* C:\Recovery\OEM\Point_D\BTBHost\*.* >> %logSpec% 2>&1
	)
)

echo ====================%date% %time%  HPMUIDIR begin =================>>%logSpec%

pushd C:\Windows\System32
.\HPMUIDir.exe
popd
echo ====================%date% %time%  HPMUIDIR finish =================>>%logSpec%

echo ====================%date% %time%  Export StartAppList begin =================>>%logSpec%
Powershell.exe -executionpolicy remotesigned -File  %~dp0\get-startapps.ps1
echo ====================%date% %time%  Export StartAppList finish =================>>%logSpec%

echo ====================%date% %time%  Copy IE Fav for CloudOS begin =================>>%logSpec%
C:\HP\HPQWare\BTBHost\Getlocale.exe
call C:\HP\HPQware\setlocale.bat
type C:\HP\HPQware\setlocale.bat >>%logSpec%
if exist "c:\hp\hpqware\Favs\All\%ISO_COUNTRY3%" (
	echo Copy IE Favorite for Windows CloudOS >>%logSpec%
	xcopy /e/i/y/f "c:\hp\hpqware\Favs\All\%ISO_COUNTRY3%" "C:\Users\Default\Favorites" >>%logSpec% 2>&1
) else (
	echo No default country IE favorite for copying >>%logSpec%
)
echo ====================%date% %time%  Copy IE Fav for CloudOS end =================>>%logSpec%

:: Export registry files for debugging.
if not exist %logs% md %logs%
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SVDEn" %logs%\Reg.asgmetro.log /y >>%logSpec% 2>&1
reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Store" %logs%\Reg.SCMID.log /y >>%logSpec% 2>&1
reg export "HKLM\SOFTWARE\HP\System Properties" %logs%\Reg.SysProp.log /y >>%logSpec% 2>&1
reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" %logs%\Reg.EnvVar.log /y  >>%logSpec% 2>&1

@echo %date% %time% BTB Post Install Finish Running>>%logs%\wizinstaller.log

popd