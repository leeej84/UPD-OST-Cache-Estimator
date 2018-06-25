﻿#
# Powershell script for estimating Exchange Mailbox Size per user
#
# Generated by: Leee Jeffries
#
# http://www.leeejeffries.com
#
# Please pay me a visit if you find this script useful
#
# Generated on: 19/06/18
#
#This script will loop through each user and shared mailbox and estimate mailbox cache usage per day and month for the life of the mailbox
#A CSV files is then exported with the details of each mailbox, useful for estimating the size of VHD containers
#
#Remember to set your export location for the CSV
#Export Location - Edit this location
$exportLocation = "C:\temp\Export.csv"

#Check if a remote powershell session exists, if not then connect one
try {
    Get-PSSession -Name ExchangeRM -ErrorAction Stop > $null
}
catch {
    #Grab User Credentials
    $UserCredential = Get-Credential

    #Set the session parameters to for the Exchange Online Powershell Session
    $Session = New-PSSession -Name "ExchangeRM" -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication  Basic -AllowRedirection

    #Import the Powershell Session for Exchange Online
    Import-PSSession $Session
}

#Fill a variable with all mailboxes
$mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox,SharedMailbox

#Create an array for mailbox objects
$objectArray = @()

#Loop through each mailbox and grab the name of the mailbox and fill a variable with mailbox items
foreach ($mailbox in $mailboxes) {
    $oldestItem = $mailbox | Get-MailboxFolderStatistics | Sort-Object CreationTime | Select-Object CreationTime -First 1
    $newestItem = Get-Date
    $mailBoxAge = New-TimeSpan -Start $oldestItem.CreationTime -End $newestItem
    
    $mailboxitems = $mailbox | Get-MailboxFolderStatistics | Select-Object Name,FolderAndSubfolderSize,ItemsInFolderAndSubfolders
    $object = New-Object –TypeName PSObject

    #Loop through all mailbox items and calculate sizes
    foreach ($mailboxitem in $mailboxitems) {
            $object = New-Object –TypeName PSObject    

            $totalSizeInMB = $totalSizeInMB + $mailboxitem.FolderAndSubfolderSize.ToString().Split("(")[1].Split(" ")[0].Replace(",","")/1MB
            $totalSizeInGB = $totalSizeInGB + $mailboxitem.FolderAndSubfolderSize.ToString().Split("(")[1].Split(" ")[0].Replace(",","")/1GB
            $totalItems = $totalItems + $mailboxitem.ItemsInFolderAndSubfolders
    }
   
    #Populate object
    $object | Add-Member –MemberType NoteProperty –Name "Mailbox Name" –Value $mailbox.Name -Force
    $object | Add-Member –MemberType NoteProperty –Name "Mailbox Size in MB" –Value ([math]::Round($totalSizeInMB,2)) -Force
    $object | Add-Member –MemberType NoteProperty –Name "Mailbox Size in GB" –Value ([math]::Round($totalSizeInGB,2)) -Force
    $object | Add-Member –MemberType NoteProperty –Name "Mailbox Items" –Value $totalItems -Force
    $object | Add-Member –MemberType NoteProperty –Name "Mailbox Age (Days)" –Value $mailBoxAge.Days -Force
    $object | Add-Member –MemberType NoteProperty –Name "Cache Per Day MB" –Value ([math]::Round($totalSizeInMB/$mailBoxAge.Days,2)) -Force
    $object | Add-Member –MemberType NoteProperty –Name "Cache Per Day GB" –Value ([math]::Round($totalSizeInGB/$mailBoxAge.Days,2)) -Force
    $object | Add-Member –MemberType NoteProperty –Name "Cache Per Month MB" –Value ([math]::Round(($totalSizeInMB/$mailBoxAge.Days)*30,2)) -Force
    $object | Add-Member –MemberType NoteProperty –Name "Cache Per Month GB" –Value ([math]::Round(($totalSizeInGB/$mailBoxAge.Days)*30,2)) -Force

    #Add to the array
    $objectArray += $object 
   
    #Clear variables
    $totalSizeinMB = 0
    $totalSizeinGB = 0
    $totalItems = 0

    "Processed - $mailbox.Name"
}

#List out array objects
$objectArray
$objectArray | Export-Csv -NoTypeInformation -Path $exportLocation



