﻿#
# Python virtual env manager inspired by VirtualEnvWrapper
#
# Copyright (c) 2017 Regis FLORET
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#
# Set the default path and create the directory if don't exist
#
$virtualenvwrapper_home = "$Env:USERPROFILE\Envs"
if ((Test-Path $virtualenvwrapper_home) -eq $false) {
    mkdir $virtualenvwrapper_home
}

#
# Get the absolute path for the environment
#
function Get-FullPyEnvPath($pypath) {
    return ("{0}\{1}" -f $virtualenvwrapper_home, $pypath)
}

# 
# Display a formated error message
#
function Write-FormatedError($err) {
    Write-Host 
    Write-Host "  ERROR: $err" -ForegroundColor Red
    Write-Host 
}

#
# Display a formated success messge
#
function Write-FormatedSuccess($err) {
    Write-Host 
    Write-Host "  SUCCESS: $err" -ForegroundColor Green
    Write-Host 
}

#
# Retrieve the python version with the path the python exe regarding the version. 
# Python < 3.3 is for this function a Python 2 because the module venv comes with python 3.3
#
# Return the major version of python 
#
function Get-PythonVersion($Python) {
    if (!(Test-Path $Python)) {
        Write-FormatedError "$Python doesn't exist"
        return
    }

    $python_version = Invoke-Expression "$Python --version 2>&1"
    if (!$Python -and !$python_version) {
        Write-Host "I don't find any Python version into your path" -ForegroundColor Red
        return 
    }

    $is_version_2 = ($python_version -match "^Python\s2") -or ($python_version -match "^Python\s3.3")
    $is_version_3 = $python_version -match "^Python\s3" -and !$is_version_2
    
    if (!$is_version_2 -and !$is_version_3) {
        Write-FormatedError "Unknown Python Version expected Python 2 or Python 3 got $python_version"
        return 
    }

    return $(if ($is_version_2) {"2"} else {"3"})
}

#
# Common command to create the Python Virtual Environement. 
# $Command contains either the Py2 or Py3 command
#
function Invoke-CreatePyEnv($Command, $Name) {
    $NewEnv = Join-Path $virtualenvwrapper_home $Name
    Write-Host "Creating virtual env... "
    
    Invoke-Expression "$Command $NewEnv"
    
    $VEnvScritpsPath = Join-Path $NewEnv "Scripts"
    $ActivatepPath = Join-Path $VEnvScritpsPath "activate.ps1"
    . $ActivatepPath

    Write-FormatedSuccess "$Name virtual environment was created and your're in."
}

#
# Create Python Environment using the VirtualEnv.exe command
#
function New-Python2Env($Python, $Name) {
    $Command = (Join-Path (Join-Path (Split-Path $Python -Parent) "Scripts") "virtualenv.exe")
    if ((Test-Path $Command) -eq $false) {
        Write-FormatedError "You must install virtualenv program to create the Python virtual environment '$Name'"
        return 
    }

    Invoke-CreatePyEnv $Command $Name
}
    
# 
# Create Python Environment using the venv module
# 
function New-Python3Env($Python, $Name) {
    if (!$Python) {
        $PythonExe = Find-Python
    } else {
        $PythonExe = Join-Path (Split-Path $Python -Parent) "python.exe"
    }

    $Command = "$PythonExe -m venv"

    Invoke-CreatePyEnv $Command $Name
}

#
# Find python.exe in the path. If $Python is given, try with the given path
#
function Find-Python ($Python) {
    if (!$Python) {
        return Get-Command "python.exe" | Select-Object -ExpandProperty Source
    }

    if (!(Test-Path $Python)) {
        return $false
    }
    
    $PythonExe = Join-Path $Python "python.exe"
    if (!(Test-Path $PythonExe)) {
        return $false
    }

    return $PythonExe
}

#
# Create the Python Environment regardless the Python version
#
function New-PythonEnv($Python, $Name, $Packages, $Append, $RequirementFile) {
    $version = Get-PythonVersion $Python
    
    BackupPath
    if ($Append) {
        $Env:PYTHONPATH = "$Append;$($Env:PYTHONPATH)"
    }

    if ($Version -eq "2") {
        New-Python2Env -Python $Python -Name $Name -Packages $Packages -RequirementFile $Requirement
    } elseif ($Version -eq "3") {
        New-Python3Env -Python $Python -Name $Name -Packages $Packages -RequirementFile $Requirement
    } else {
        Write-FormatedError "This is the debug voice. I expected a Python version, got $Version"
        RestorePath
    }
}

function BackupPath {
    $Env:OLD_PYTHON_PATH = $Env:PYTHONPATH
}

function RestorePath {
    $Env:PYTHONPATH = $Env:OLD_PYTHON_PATH
    $Env:Path = $Env:OLD_SYSTEM_PATH
}

# 
# Test if there's currently a python virtual env
#
function Get-IsInPythonVenv($Name) {
    if ($Env:VIRTUAL_ENV) {
        if ($Name) {
            if (([string]$Env:VIRTUAL_ENV).EndsWith($Name)) {
                return $true
            }

            return $false;
        }

        return $true
    }

    return $false
}

# Now, work on a env
function workon {
    Param(
        [string] $Name
    )

    if (Get-IsInPythonVenv -eq $true) {
        Deactivate
    }

    if (!$Name) {
        Write-FormatedError "No python venv to work on. Did you forget the -Name option?"
        return
    }

    $new_pyenv = Get-FullPyEnvPath $Name
    if ((Test-Path $new_pyenv) -eq $false) {
        Write-FormatedError "The Python environment '$Name' don't exists. You may want to create it with 'MkVirtualEnv $Name'"
        return
    }

    $activate_path = "$new_pyenv\Scripts\Activate.ps1"
    if ((Test-path $activate_path) -eq $false) {
        Write-FormatedError "Enable to find the activation script. You Python environment $Name seems compromized"
        return
    }
    
    . $activate_path
}

# 
# Create a new virtual environment. 
#
function New-VirtualEnv {
    Param(
        [Parameter(HelpMessage="The virtual env name")]
        [string]$Name,

        [Parameter(HelpMessage="The requirements file")]
        [alias("r")]
        [string]$RequirementFile,

        [Parameter(HelpMessage="The Python directory where the python.exe lives")]
        [string]$Python,

        [Parameter(HelpMessage="The package to install. Repeat the parameter for more than one")]
        [alias("i")]
        [string[]]$Packages,

        [Parameter(HelpMessage="Add an existing project directory to the new environment")]
        [alias("a")]
        [string]$Append
    )

    if ($Append -and !(Test-Path $Append)) {
        Write-FormatedError "The path '$Append' doesn't exist"
        return
    }

    if (!$Name) {
        Write-FormatedError "You must at least give me a PyEnv name"
        return
    }

    if ((IsPyEnvExists $Name) -eq $true) {
        Write-FormatedError "There is an environment with the same name"
        return
    }

    $PythonRealPath = Find-Python $Python
    if (!$PythonRealPath) {
        Write-FormatedError "The path to access to python doesn't exist. Python directory = $Python"
        return
    }

    New-PythonEnv -Python $PythonRealPath -Name $Name -Packages $Packages -Append $Append  -RequirementFile $Requirement
}


#
# Check if there is an environment named $Name
#
function IsPyEnvExists($Name) {
    $children = Get-ChildItem $virtualenvwrapper_home

    if ($children.Length -gt 0) {
        for ($i=0; $i -lt $children.Length; $i++) {
            if (([string]$children[$i]).CompareTo($Name) -eq 0) {
                return $true
            }
        }
    }

    return $false
}

function Get-VirtualEnvs {
    $children = Get-ChildItem $virtualenvwrapper_home
    Write-Host
    Write-Host "`tPython Virtual Environments available"
    Write-Host
    Write-host ("`t{0,-30}{1,-15}" -f "Name", "Python version")
    Write-host ("`t{0,-30}{1,-15}" -f "====", "==============")
    Write-Host

    if ($children.Length) {
        for($i = 0; $i -lt $children.Length; $i++) {
            $child = $children[$i]
            $PythonVersion = (((Invoke-Expression ("$virtualenvwrapper_home\{0}\Scripts\Python.exe --version 2>&1" -f $child)) -replace "`r|`n","") -Split " ")[1]
            Write-host ("`t{0,-30}{1,-15}" -f $child,$PythonVersion)
        }
    } else {
        Write-Host "`tNo Python Environments"
    }
    Write-Host
}

#
# Remove a virtual environment.
#
function Remove-VirtualEnv {
    Param(
        [string]$Name
    )
    
    if ((Get-IsInPythonVenv $Name) -eq $true) {
        Write-FormatedError "You want to destroy the Virtual Env you are in. Please type 'deactivate' before to dispose the environment before"
        return
    }

    if (!$Name) {
        Write-FormatedError "You must fill a environmennt name"
        return
    }

    $full_path = Get-FullPyEnvPath $Name
    if ((Test-Path $full_path) -eq $true) {
        Remove-Item -Path $full_path -Recurse 
        Write-FormatedSuccess "$Name was deleted permantly"
    } else {
        Write-FormatedError "$Name not found"
    }
}

#
# Powershell alias for naming convention
#
#Set-Alias Get-VirtualEnvs lsvirtualenv 
#Set-Alias Remove-VirtualEnv rmvirtualenv
#Set-Alias New-VirtualEnv mkvirtualenv