<############################################################################## 
AWS AMI Upgrade to TPM
Summary: This script builds the commands to upgrade an AWS instance to
    an AMI type that has UEFI boot and TPM enabled. Requires source
    instance ID. Does not work on instances with more than one attached
    network interface.
Created by Stephen Hensel
Date : 26 JUL 2024
Version : 0.4
##############################################################################>

#Set Error Action Preference
$ErrorActionPreference = "Stop"

 #import Modules
Import-Module AWS.Tools.Common
Import-Module AWS.Tools.EC2

#Variables
$ScriptName = "AWS AMI Upgrade"
$ReportName = $ScriptName
$today = Get-Date -Format "MM_dd_yyyy"

#Filepath Check
$ScriptPathReports=("$env:HOMEDRIVE\Scripts\Reports\" + $ScriptName)
$scriptPathLog=("$env:HOMEDRIVE\Scripts\Reports\" + $ScriptName + "\Log")
$Path_Reports=Get-Item $ScriptPathReports -ErrorAction SilentlyContinue
$Path_Log=Get-Item $scriptPathLog -ErrorAction SilentlyContinue
if ($null -eq $Path_Reports) {
    MKDIR $ScriptPathReports -Force
} Else {
    Write-Output "Path '$ScriptPathReports' already exists."
}
if ($null -eq $Path_Log) {
    MKDIR $scriptPathLog -Force
} Else {
    Write-Output "Path '$scriptPathLog' already exists."
}

#Record for logging
start-transcript -path "$env:HOMEDRIVE\Scripts\Reports\$ScriptName\Log\$ReportName ($today)_log.txt" -Append -Force

#Get source instance ID
do {
    $sourceInstanceID = Read-Host "Enter source Instance ID"

    $sourceInstanceID
    $answer = Read-Host "Is this correct? (y/n)"
} until ($answer -eq "y")

#Get root and non-root volumeId from source instance
    #Get root volume on source instance
    $filter_name = New-Object Amazon.EC2.Model.Filter -Property @{Name = "attachment.instance-id"; Values = $sourceInstanceID}
    $volumes = Get-EC2Volume -Filter $filter_name
    $rootVolume = foreach ($volume in $volumes) {
        if (((Get-EC2Volume -VolumeId $volume.volumeId).Attachments).Device -eq "/dev/sda1") {
            [PSCustomObject]@{
                volumeID = $volume.VolumeId
                device = ((Get-EC2Volume -VolumeId $volume.volumeId).Attachments).Device
            }
        }
    }
    Write-Output "Root volume:"
    $rootVolume | Format-List

    #Get all non-root volumes on source instance
    $filter_name = New-Object Amazon.EC2.Model.Filter -Property @{Name = "attachment.instance-id"; Values = $sourceInstanceID}
    $volumes = Get-EC2Volume -Filter $filter_name
    $mountVolumes = foreach ($volume in $volumes) {
        if (((Get-EC2Volume -VolumeId $volume.volumeId).Attachments).Device -ne "/dev/sda1") {
            [PSCustomObject]@{
                volumeID = $volume.VolumeId
                device = ((Get-EC2Volume -VolumeId $volume.volumeId).Attachments).Device
            }
        }
    }
    Write-Output "Non-Root volumes:"
    $mountVolumes | Format-List

#Shutdown source instance
Write-Output "Stopping instance $sourceInstanceID ..."
Stop-EC2Instance -InstanceID $sourceInstanceID
$sleep = 0
do {
    Start-Sleep -Seconds 5
    $sleep = $sleep + 5
    Write-Output "Waiting for instance to stop ... ($sleep sec)"
} while ((Get-EC2InstanceStatus -IncludeAllInstance:$true  -InstanceId $sourceInstanceID).InstanceState.Name.Value -ne "Stopped")
Write-Output "Stopping instance $sourceInstanceID ... Done"

#Take snapshot of source instance root drive
Write-Output "Taking snapshot of root volume $rootVolume ..."
$rootSnapshot = New-EC2Snapshot -VolumeId $rootVolume.volumeID -Description "Pre-AMI Upgrade"
$sleep = 0
do {
    Start-Sleep -Seconds 5
    $sleep = $sleep + 5
    Write-Output "Waiting for snapshot to complete ... ($sleep sec)"
} while ((Get-EC2Snapshot -SnapshotId $rootSnapshot.SnapshotId).State.Value -ne "completed")
Write-Output "Taking snapshot of root volume $rootVolume ... Done"
Write-Output $rootSnapshot

#Build EBS Block Device
$blockDeviceMapping=New-Object -TypeName Amazon.EC2.Model.BlockDeviceMapping
$ebsBlockDevice = new-object -typename amazon.ec2.model.ebsblockdevice
$blockDeviceMapping.DeviceName='/dev/sda1'
$ebsBlockDevice.DeleteOnTermination=$true
$ebsBlockDevice.SnapshotId=$rootSnapshot.SnapshotId
$blockDeviceMapping.ebs=$ebsBlockDevice

#Build EC2Image
    do {
        $name= Read-Host "Enter AMI name"
        $description = Read-Host "Enter AMI Description"
        
        $name
        $description
        $answer = Read-Host "Is this correct? (y/n)"
    } until ($answer -eq "y")

    #Create AMI
    Write-Output "Generating AMI ... "
    $RegEC2Props = @{
        region="US-East-2"
        description=$description
        name=$name
        blockdevicemapping=$blockDeviceMapping
        architecture="x86_64"
        rootdevicename="/dev/sda1"
        virtualizationtype="hvm"
        enasupport=$true
        TpmSupport="v2.0"
        bootmode="uefi"
        uefidata="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"
    }
 
    Register-EC2Image @RegEC2Props
    Write-Output "Generating AMI ... Done"

#Create new instance
    #Populate instance settings
    $instanceSettings = (Get-EC2Instance -InstanceId $sourceInstanceID).Instances
    $filter_name = New-Object Amazon.EC2.Model.Filter -Property @{Name = "name"; Values = $name}
    $sourceAMI = Get-EC2Image -Owner self -Filter $filter_name
    $instanceType = $instanceSettings.InstanceType

    #Ensure instance type is correct
    do {
        Write-Output "New instance type is $instanceType"
        $answer = Read-Host "Is this correct? (y/n)"

        if ($answer -eq "n") {
            $instanceType = Read-Host "Enter Instance Type"
        }
    } until ($answer -eq "y")

    #Disable termination protection on source instance
    Write-Output "Disabling termination protection for $sourceInstanceID ..."
    Edit-EC2InstanceAttribute -InstanceID $sourceInstanceID -DisableApiTermination $false
    Write-Output "Disabling termination protection for $sourceInstanceID ... Done"

    #Disable deletion of source instance network interface
    Write-Output "Disabling delete on termination for network interface ..."
    $EditEC2NetInterface = @{
        NetworkInterfaceId=(Get-Ec2Instance -InstanceID $sourceInstanceID).Instances.NetworkInterfaces.NetworkInterfaceId
        Attachment_AttachmentId=(Get-EC2Instance -InstanceID $sourceInstanceID).Instances.NetworkInterfaces.Attachment.AttachmentId
        Attachment_DeleteOnTermination=$false
    }
    Edit-EC2NetworkInterfaceAttribute @EditEC2NetInterface
    Write-Output "Disabling delete on termination for network interface  ... Done"

    #Terminate source instance
    Write-Output "Terminating instance $sourceInstanceID ..."
    Remove-EC2Instance -InstanceID $sourceInstanceID
    $sleep = 0
    do {
        Start-Sleep -Seconds 5
        $sleep = $sleep + 5
        Write-Output "Waiting for instance to terminate ... ($sleep sec)"
    } while ((Get-EC2InstanceStatus -IncludeAllInstance:$true -InstanceId $sourceInstanceID).InstanceState.Name.Value -ne "terminated")
    Write-Output "Terminating instance $sourceInstanceID ... Done"

    #Map Network Interface for addition to new instance
    $NetworkInterfaces = @{
        DeviceIndex=0
        NetworkInterfaceId=$instanceSettings.NetworkInterfaces.NetworkInterfaceID
    }
    #Create new instance
    Write-Output "Creating new instance ... "
    $NewEC2Props = @{
        ImageID=$sourceAMI.ImageID
        MinCount=1
        MaxCount=1
        InstanceType=$instanceType
        KeyName=$instanceSettings.KeyName
        NetworkInterfaces=$NetworkInterfaces
    }
    $NewInstanceResponse = New-EC2Instance @NewEC2Props
    $NewInstance = ($NewInstanceResponse.Instances).InstanceID
    New-EC2Tag -ResourceID $newInstance -Tags $instanceSettings.Tags
    $sleep = 0
    do {
        Start-Sleep -Seconds 5
        $sleep = $sleep + 5
        Write-Output "Waiting for instance to start ... ($sleep sec)"
    } while ((Get-EC2InstanceStatus -IncludeAllInstance:$true -InstanceId $NewInstance).InstanceState.Name.Value -ne "running")
    Write-Output "Creating new instance $newInstance ... Done"

#Move non-root volumes to new instance
foreach ($volume in $mountVolumes) {
    Write-Output "Mounting $volume.volumeId ... "
    Add-EC2Volume -InstanceID $NewInstance -VolumeId $volume.volumeId -Device $volume.device
    Write-Output "Mounting $volume.volumeId ... Done"
}

#Stop Recording
Stop-Transcript
