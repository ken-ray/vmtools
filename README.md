Download and Unzip PS_VM_Tools.zip (or download all of the files individually)

From Powershell:

1) install-module vmware.powercli -Force -AllowClobber  (it will probably update NuGet, as well, and may take a while)

2) change to directory of unzipped ps_vm_tools files (or where you downloaded all of the files)

3) unblock-file *.ps1  (to get rid of the pesky "do you trust this file?" messages)

4) Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false (wait a bit and input A and press Enter)

5) run VMToolkit.ps1


Note: The first time you connect to vCenter it will be slow (~35 seconds to connect).
