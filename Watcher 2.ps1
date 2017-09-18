#Notes
# - When you start the Watcher, logs are cleared.
# - If you notice files aren't being copied, try running as Admin

$folder = 'C:\'
$filter = '*.*'

#If you change any of the following, make sure you reflect the changes in the $script* variables
$outputFolder = 'C:\Output' #Don't end the string with \ or /
$outputLog = 'C:\Users\Alex\Desktop\Watcher.log'
$whiteLog = 'C:\Users\Alex\Desktop\Watcher_white.log'
$csvFile = 'C:\Users\Alex\Desktop\Watcher.csv'

$verbose = $true #Write to console + Write whitelist events (super noisy)

$whiteFolders = 'C:\NotTesting\','C:\Testing\' #I think it's case insensitive
$whiteFiles = 'NTUSER.DAT','ntuser.dat.LOG1' #I think it's case insensitive
$whiteExtensions = '.nerd','.fart' #Include period i.e. '.exe' not 'exe'

$scriptFiles = $outputLog,$whiteLog,$csvFile
$scriptFolders = $outputFolder

$fsw = New-Object IO.FileSystemWatcher($folder, $filter)
$fsw.IncludeSubdirectories = $true

$eventHandler = { #When an event triggers, this code block gets called/executed
    $changeType = $Event.SourceEventArgs.ChangeType
    $name = $Event.SourceEventArgs.FullPath
    $timeStamp = $Event.TimeGenerated
    $fileHandle = [IO.FileInfo]$name

    $onlyName = Split-Path $name -leaf
    $onlyPath = Split-Path $name -parent
    #Whitelisting
    ForEach($scriptFile in $scriptFiles){
        if($name -eq $scriptFile){
            Write-Host 'fuuu'
            break
        }
    }

    $whiteFlag = $true
    ForEach($whiteFolder in $whiteFolders){
        if($onlyPath -like "$whiteFolder*"){
            $whiteFlag = $false
        }
    }
    ForEach($whiteFile in $whiteFiles){
        if($onlyName -like "*$whiteFile*"){
            $whiteFlag = $false
        }
    }
    if($fileHandle.Extension){
        ForEach($whiteExtension in $whiteExtensions){
            if($fileHandle.Extension -eq $whiteExtension){
                $whiteFlag = $false
            }
        }
    }
    #Only process Folder create/delete
    if(([IO.FileInfo]$name).Attributes -match 'Directory' -And $changeType.ToString() -eq 'Changed'){
        $whiteFlag = $false
    }
    
    if($whiteFlag){
        #Console out color selection
        If($changeType.ToString() -eq 'Created'){ $tColor = 'green' }
        ElseIf($changeType.ToString() -eq 'Deleted'){ $tColor = 'red' }
        ElseIf($changeType.ToString() -eq 'Changed'){ $tColor = 'white' }
        ElseIf($changeType.ToString() -eq 'Renamed'){ $tColor = 'yellow' }
        #Make a copy of the file except for on Rename event
        if($changeType.ToString() -ne 'Renamed'){
            Try {
                if($fileHandle.Extension) {
                    $extension = $fileHandle.Extension.TrimStart('.')
                    New-Item -ItemType Directory -Force -Path "$outputFolder\$extension\"
                    Copy-Item $name -Destination "$outputFolder\$extension\" -Force
                } Else {
                    Copy-Item $name -Destination "$outputFolder\CatchAll\" -Force
                }
            } Catch [system.exception] {
                pass
            }
        }
        #Output to txt, csv, and console
        Out-File -FilePath $outputLog -Append -InputObject "'$name'`t$changeType`t$timeStamp"
        echo "'$name'`t$changeType`t$timeStamp" >> $csvFile
        if($verbose){ Write-Host "'$name' `t $changeType `t $timeStamp" -fore $tColor }
    } Else {
        if($verbose) { Out-File -FilePath $whiteLog -Append -InputObject "'$name'`t$changeType`t$timeStamp" }
    }
}

function addWhite {
    $whiteType = $args[0]
    $whiteValue = $args[1]
    switch ($whiteType) {
        'extension' { $global:whiteExtensions += $whiteValue }
        'folder' { $global:whiteFolders += $whiteValue }
        'file' { $global:whiteFiles += $whiteValue }
    }
}

function stopW { #Ends the watch
    Unregister-Event FileCreated
    Unregister-Event FileDeleted  
    Unregister-Event FileChanged
    Unregister-Event FileRenamed
}

function startW { #Starts the watch
    purgeLog
    Register-ObjectEvent $fsw Created -SourceIdentifier FileCreated -Action $eventHandler
    Register-ObjectEvent $fsw Deleted -SourceIdentifier FileDeleted -Action $eventHandler
    Register-ObjectEvent $fsw Changed -SourceIdentifier FileChanged -Action $eventHandler
    Register-ObjectEvent $fsw Renamed -SourceIdentifier FileRenamed -Action $eventHandler
}

function purgeLog {
    New-Item -Path $outputLog -ItemType File -Force
    New-Item -Path $csvFile -ItemType File -Force
    New-Item -Path $whiteLog -ItemType File -Force
    echo "Name`tChange`tTime" >> $csvFile
}