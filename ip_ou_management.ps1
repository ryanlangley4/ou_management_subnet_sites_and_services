

#I used hash tables in this way as I feel it is more intuative for configuration than a multi-array.
$Org_List = @{"192.168.0.0/28" = "ou=site1,dc=test,dc=local"; 
			  "192.168.3.0/24" = "ou=site2,dc=test,dc=local";
		      "172.16.0.0/24" = "ou=site2,dc=test,dc=local"}


#Configure 
$Computer_List = get-adcomputer -filter { Enabled -eq $true } -searchbase "CN=computers,DC=test,dc=local" | select DnsHostName, DistinguishedName
			  
#OutPut the max Range for the provide ip and CIDR 192.168.0.0/24 is the expected format
function find-ipcidr() {
	Param( 	[Parameter(Mandatory = $true)]$IP_Cidr )

$Ip_Cidr = $IP_Cidr.Split("/")
$Ip_Bin = ($IP_Cidr[0] -split '\.' | ForEach-Object {[System.Convert]::ToString($_,2).PadLeft(8,'0')}).ToCharArray()
	for($i=0;$i -lt $Ip_Bin.length;$i++){
		if($i -ge $Ip_Cidr[1]){
		$Ip_Bin[$i] = "1"
		} 
	}

[string[]]$IP_Int = @()
	for($i = 0;$i -lt $Ip_Bin.length;$i++) {
	$PartIpBin += $Ip_Bin[$i] 
		if(($i+1)%8 -eq 0){
		$PartIpBin = $PartIpBin -join ""
		$IP_Int += [Convert]::ToInt32($PartIpBin -join "",2)
		$PartIpBin = ""
		}
	}

$IP_Int = $IP_Int -join "."
return $IP_Int
}

#convert the provided IP into an 32 bit integer in order to easier work with in it.
function ip_to_int32(){
	Param( 	[Parameter(Mandatory = $true)]$IP_int32 )
$IP_int32_arr = $IP_int32.split(".")
$return_int32 = ([Convert]::ToInt32($IP_int32_arr[0])*16777216 +[Convert]::ToInt32($IP_int32_arr[1])*65536 +[Convert]::ToInt32($IP_int32_arr[2])*256 +[Convert]::ToInt32($IP_int32_arr[3])) 
return $return_int32
}

#Go through the list of computers gathered at the top of the script, get the ip address via DNS.
#Find the max range for each value in the hash table and if the ip falls into that range move the computer object to corresponding OU.
foreach($computer in $computer_list) {
$Comp_Dns = $computer.DnsHostName
	try {
	$Comp_IP = [System.Net.Dns]::GetHostAddresses("$Comp_Dns") | where-object { $_.AddressFamily -eq 'InterNetwork'} | select -expandproperty IPAddressToString
	} catch {
	echo "Error On lookup of $Comp_Dns :  $_"
	$Comp_IP = $FALSE
	}
	
	if($Comp_IP) {
		foreach($ip_info in $Org_List.GetEnumerator().Name) {
		$start_of_range_arr = $ip_info.Split("/") 
		[string] $start_of_range_value = $start_of_range_arr[0]
		$start_of_range_int32 = ip_to_int32 $start_of_range_value

		$end_of_range_value = Find-CidrRange $ip_info
		$end_of_range_int32 = ip_to_int32 $end_of_range_value
		
		$search_ip_int32 = ip_to_int32 $Comp_IP
		
		echo "Start: $start_of_range_value End: $end_of_range_value Looking for: $comp_ip"
			if(($search_ip_int32 -ge $start_of_range_int32) -and ($search_ip_int32 -le $end_of_range_int32)) {
			echo "Found $comp_ip"
			$DistinguishedName = $computer.DistinguishedName
			try {
			Move-ADObject -identity "$DistinguishedName" -TargetPath $Org_List."$ip_info"			
			} catch {
			echo "Error On moving $Comp_Dns :  $_"
			}
			} 
		}
	}
}