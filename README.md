# AWS-AMI-upgrade
Upgrades an AWS instance to one supporting TPM and GPT boot

## Usage
**DO NOT RUN UNLESS ROOT DISK HAS BEEN CONVERTED TO GPT BOOT TYPE!**

**USING THIS SCRIPT ON AN INSTANCE WITH MBR BOOT TYPE WITH RESULT IN AN UNSUABLE INSTANCE!**

**Use mbr2gpt tool on the instance first!**

**Note: Script will not run correctly on an instance with multiple network interfaces attached.**

To use, download and run from a second instance with the latest version of [AWS PowerShell Tools](https://docs.aws.amazon.com/powershell/latest/userguide/pstools-welcome.html) installed and has a properly set up [AWAS Profile](https://docs.aws.amazon.com/powershell/latest/userguide/creds-idc.html). Verify the correct region for AMI generation (default is US-East-2).

The script will prompt for an EC2 instance ID and confirm the state of the instance, then ask for user confirmation. It will throw an error and end if the state is terminated or terminating.

It will then automatially collect information on attached volumes and stop the instance if it is not already stopped before taking a snapshot of the root volume. Should the instance be in a state other than running or stopped, the script will throw an error and end.

A snapshot will be taken of the instance's root volume and the script will prompt for an AMI name and description for building a new AMI with UEFI boot and TPM enabled.

The script will prompt confirmation of the new instance type based on the source instance's type and allow that type to be changed if desired. It will then disable termination protection on the source instance and prompt for authorization to disable delete on termination for the network interface.

Once authorized, the source instance will be automatically terminated and a new instance built from the AMI previously created. Non-root volumes from the source instance will be attached to the new instance.

## Contributing
Before modifying, check the latest AWS PowerShell Tools and commands for compatability. Also check data structures for EC2 instances and AMIs.

## Project Status
No significant code changes are anticipated. Nitro is the default instance platform now, so upgrades should not be required for new instances.
