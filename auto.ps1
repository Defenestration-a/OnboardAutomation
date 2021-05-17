
#To invoke run ./auto.ps1 10 P4ssw0rd

#first we're invoking this to force TLS1.2 connection, because of bamboo HR and we also need to load this .dll to get the Azure module stuff to work.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -Path 'C:\Program Files\WindowsPowerShell\Modules\AzureAD\2.0.2.16\Microsoft.Open.AzureAD16.Graph.Client.dll'

#Take in ARGS
$id = $Args[0]
$userpassword = $Args[1]

#Takes bambooHR employee profile and generates an XML file with from it. We generate two names, because the data is in two tables
$uri = "https://api.bamboohr.com/api/gateway.php/THEREWASABUSINESSHERE/v1/employees/$id`?fields=fullName1,workEmail,department,firstName,lastName,preferredName,customMentor"
$uname = "THEREWASATOKENHERENOWTHEREISNT"
$uripassword = 'APASSWORD'
$secpwd = ConvertTo-SecureString $uripassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($uname, $secpwd)
Invoke-RestMethod -Method Get -Uri $uri -Credential $credential -OutFile names.xml

$ura = "https://api.bamboohr.com/api/gateway.php/THEREWASABUSINESSHERE/v1/employees/$id/tables/jobInfo"
Invoke-RestMethod -Method Get -Uri $ura -Credential $credential -OutFile job.xml


#takes in the xml file we just generated
[xml]$departmentint = Get-Content job.xml
$department = $departmentint.SelectSingleNode("table/row/field[@id=`"department`"]").InnerText

#takes in the other xml file we just generated
[xml]$inputs = Get-Content names.xml

#Parses bamboo HRs XML file for things we need, mailnick is first.last
$displayname = $inputs.SelectSingleNode("/employee/field[@id=`"fullName1`"]").InnerText
$lastname = $inputs.SelectSingleNode("/employee/field[@id=`"lastName`"]").InnerText
$firstname = $inputs.SelectSingleNode("/employee/field[@id=`"firstName`"]").InnerText
$mentor = $inputs.SelectSingleNode("/employee/field[@id=`"customMentor`"]").InnerText
$prefername = $inputs.SelectSingleNode("/employee/field[@id=`"preferredName`"]").InnerText
$mailnick = "$firstname.$lastname"
$mailnick = "$mailnick".ToLower()
$principalname = "$mailnick@THEREWASABUSINESSHERE.com"

#displays the stuff we just took in to the console as a sanity/troubleshooting check
$principalname
$displayname
$department
$firstname
$lastname
$mailnick
$prefername 
$mentor

#If there's a prefered name on bamboohr we adjust the mail, display, and principle name to the prefered name.
if ($prefername -eq "")
{
write-host( "No prefer name needed")
}
else
{
$firstname = $prefername
$mailnick = "$firstname.$lastname"
$mailnick = "$mailnick".ToLower()
$principalname = "$mailnick@THEREWASABUSINESSHERE.com"
$displayname = "$firstname $lastname"
}

#create GMAIL user using a Powershell module I found on the internet, this module has been lost to time, however; it saved a lot of work developing this as the rest of the modules I found wouldn't work
$Newuser = New-GAUserObj -ChangePasswordAtNextLogin $True -PrimaryEmail "$principalname" 
New-GAUser -Password "$userpassword" -GivenName "$firstname" -FamilyName "$lastname"  -UserName "$principalname"

#converts their password to a secure string to be taken by Azure
$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = "$userpassword"

#Admin account needed. generate cred.txt by using the following: read-host -assecurestring | ConvertFrom-SecureString | Out-File cred.txt
$adminname = "THEREWASAUSERNAMEHERE"
$adminpass = get-content creds.txt | convertto-securestring
$creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $adminname,$adminpass
Connect-AzureAD -Credential $creds


#creates new Azure User using the microsoft AzureAD module, the pause is there, because it takes a second for azure changes to be worked with for reasons? A 2 second pause fixes this, but there might be a 
New-AzureADUser -PasswordProfile $PasswordProfile -GivenName $firstname -Surname $lastname -DisplayName $displayname -UserPrincipalName $principalname -MailNickName $mailnick -AccountEnabled $true
Write-Host "Waiting on Azure to Catch up. 2 Seconds"
Start-Sleep -verbose -Seconds 2
Write-Host "Azure has caught up probably"

#Grabs the new users object ID
$user = Get-AzureAdUser -ObjectID "$principalname"


#Adds the user to their departments Azure Group using a system of elseif statements, if their department is a new department, is changed, or what ever it tells you to go assign manually. 
if ($department -eq "Project Engineering" -or $department -eq "Program Management"){
Add-AzureADGroupMember -ObjectId THEREWASANOBJECTIDHERE -RefObjectId $user.ObjectId
$departmentn = "Operations"
}
elseif ($department -eq "QA"){
Add-AzureADGroupMember -ObjectId THEREWASANOBJECTIDHERE -RefObjectId $user.ObjectId
$departmentn = "QA"
}
else{ 
write-host "There's been an issue; please assign them manually."
exit
 }

 #end of azure onboarding
 
 #start of slack onboarding, this slack api call isn't actually officially supported and has broken before. If it fails you'll get an error, but it won't break so you can go and add them manually
 $slackcontent = 'application/x-www-form-urlencoded' 
 $slackmethod = 'Post'
 $slackuri = 'https://THEREWASABUSINESSHERE.slack.com/api/users.admin.invite'
   

 #body data for slack
$slackdata = @{
    token = 'THEREWASATOKENHERENOWTHEREISNT'
    set_active = 'false'
    channels = 'ChannelUUID,for,slack'
    real_name = "$displayname"
    email = "$principalname"
    team_id = 'teamid'
    }

#sends invite
Invoke-RestMethod -uri $slackuri -method $slackmethod -ContentType $slackcontent -body $slackdata
#end slack


#This part is super WIP Microsoft doesn't support word automation, but this is as close as I could get. What I do is I create onboardinput.csv with the below columns.
#There is an oboarding packet that goes along with this that takes advantage of words mail merge to generate the onboarding packet with only a few clicks.
 
$obj = new-object PSObject
$obj | add-member -membertype NoteProperty -name "First_Name" -value "$firstname"
$obj | add-member -membertype NoteProperty -name "Email" -value "$principalname"
$obj | add-member -membertype NoteProperty -name "Mentor" -value "$mentor"
$obj | add-member -membertype NoteProperty -name "Temporary_Password" -value "$userpassword"
$obj | add-member -membertype NoteProperty -name "Extension" -value "NA"
$obj | add-member -membertype NoteProperty -name "Team" -value "$Departmentn"

$file = "onboardinput.csv"

$obj | Export-Csv -Path $file -Append -NoTypeInformation -f

#Post Mortem
#This was a good project to do in powershell and has saved me a lot of time. For a V2, I would probably do this in python as gmail automation in powershell was rough to work out
#also I would look to see if I could utilize something like LATEX or something to automate the onboarding packet instead of this csv -> mail merge thing.