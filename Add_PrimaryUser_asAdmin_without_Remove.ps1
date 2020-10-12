$Log_File = "c:\windows\debug\Add_local_admin.log"
Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"			
		write-host  "$MyDate - $Message_Type : $Message"		
	}
	
If(!(test-path $Log_File)){new-item $Log_File -type file -force}			
$Module_Installed = $False
If(!(Get-Module -listavailable | where {$_.name -like "*Microsoft.Graph.Intune*"})) 
	{
		Install-Module Microsoft.Graph.Intune -ErrorAction SilentlyContinue
		Write_Log -Message_Type "INFO" -Message "Graph Intune module has been installed"
		$Module_Installed = $True
	} 
Else 
	{ 
		Import-Module Microsoft.Graph.Intune -ErrorAction SilentlyContinue
		Write_Log -Message_Type "INFO" -Message "Graph Intune module has been imported"	
		$Module_Installed = $True		
	}

If($Module_Installed -eq $True)
	{
		$Intune_Connected = $False
		$tenant = "Your tenant"
		$authority = "https://login.windows.net/$tenant"
		$clientId = "Your client ID"
		$clientSecret = "Your secret"
		Update-MSGraphEnvironment -AppId $clientId -Quiet
		Update-MSGraphEnvironment -AuthUrl $authority -Quiet
		Try
		{
			Connect-MSGraph -ClientSecret $ClientSecret -Quiet
			Write_Log -Message_Type "SUCCESS" -Message "Connexion OK to Intune"		
			$Intune_Connected = $True		
		}
		Catch
		{
			Write_Log -Message_Type "ERROR" -Message "Connexion KO to Intune"				
		}

		If($Intune_Connected -eq $True)
			{
				$Computer = $env:COMPUTERNAME
				$Device_Found = $False
				Try
				{
					$Get_MyDevice_Infos = Get-IntuneManagedDevice | where {$_.devicename -eq $Computer}
					Write_Log -Message_Type "INFO" -Message "Device $Computer has been found on Intune"	
					$Device_Found = $True				
				}
				Catch
				{
					Write_Log -Message_Type "INFO" -Message "Device $Computer has not been found on Intune"					
					$Device_Found = $False				
				}
				
				If($Device_Found -eq $True)
					{
						$Get_MyDevice_ID = $Get_MyDevice_Infos.id
						Write_Log -Message_Type "INFO" -Message "Device ID is: $Get_MyDevice_ID"				

						$graphApiVersion = "beta"
						$Resource = "deviceManagement/managedDevices"
						$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $Get_MyDevice_ID + "/users"
						$Get_Primary_User_ID = (Invoke-MSGraphRequest -Url $uri -HttpMethod Get).value.id
						Write_Log -Message_Type "INFO" -Message "Primary user ID is: $Get_Primary_User_ID"				

						function Convert-ObjectIdToSid
						{
							param([String] $ObjectId)
							$d=[UInt32[]]::new(4);[Buffer]::BlockCopy([Guid]::Parse($ObjectId).ToByteArray(),0,$d,0,16);"S-1-12-1-$d".Replace(' ','-')
						}
						$Get_SID = Convert-ObjectIdToSid $Get_Primary_User_ID
						Write_Log -Message_Type "INFO" -Message "Primary user SID is: $Get_SID"				

						$Get_Local_AdminGroup = Gwmi win32_group -Filter "Domain='$env:computername' and SID='S-1-5-32-544'"
						$Get_Local_AdminGroup_Name = $Get_Local_AdminGroup.Name
						Write_Log -Message_Type "INFO" -Message "Admin group name is: $Get_Local_AdminGroup_Name"				


						Try
						{
							$ADSI = [ADSI]("WinNT://$Computer")
							$Group = $ADSI.Children.Find($Get_Local_AdminGroup_Name, 'group') 
							$Group.Add(("WinNT://$get_sid"))							
							Write_Log -Message_Type "SUCCESS" -Message "$Get_SID has been added in $Get_Local_AdminGroup_Name"				
						}
						Catch
						{
							Write_Log -Message_Type "ERROR" -Message "$Get_SID has not been added in $Get_Local_AdminGroup_Name"				
						}
					}
			}
	}
Else
	{
		Write_Log -Message_Type "INFO" -Message "Graph Intune module has not been imported"		
	}
