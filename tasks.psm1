$GO_VERSION = "1.14"

<#
.SYNOPSIS
Install dependencies

.DESCRIPTION
Ensure all dependencies and tools are installed

.EXAMPLE
Install-Project
#>
Function Install-Project {
	Confirm-Environment
	Write-Info "checking dependencies"
	If ((go mod verify) -And (Assert-ExitCode 0)) {
		Write-Success "all modules verified"
	}
	Else {
		Write-Warning "failed to verify modules"
	}
	Install-Hooks
	Write-Success "project installed"
}

<#
.SYNOPSIS
Verify the build environment

.DESCRIPTION
Verify the build environment is set up correctly

.EXAMPLE
Confirm-Environment
#>
Function Confirm-Environment {
	Write-Info "checking environment"
	if (-Not (Get-Command -Name go -ErrorAction SilentlyContinue)) {
		Write-Error "go is required"
	}
	if ($env:GO111MODULE -ne "on") {
		Write-Warning "go modules should be enabled"
	} else {
		Write-Success "go modules are enabled"
	}
	if (-Not (go version | Select-String -SimpleMatch "go$GO_VERSION")) {
		Write-Warning "go v$GO_VERSION should be installed"
	} else {
		Write-Success "go v$GO_VERSION is installed"
	}
	if (-Not (Get-Command -Name "golangci-lint" -ErrorAction SilentlyContinue)) {
		Write-Warning "golangci-lint should be installed"
	} else {
		Write-Success "golangci-lint is installed"
	}
}

<#
.SYNOPSIS
Install git hooks

.DESCRIPTION
Copy this project's git hooks into the .git directory

.EXAMPLE
Install-Hooks
#>
Function Install-Hooks {
	New-Item -Type Directory -Force (Join-Path ".git" "hooks") > $null
	ForEach ($file in (Get-ChildItem (Join-Path "hooks" "*.*"))) {
		# Get name without extension
		$name = ($file.Name -Split '\.')[0]
		$dest = (Join-Path ".git" "hooks" $name)
		Write-Info "installing $name hooks"

		Copy-Item $file $dest
		if (Get-Command chmod -ErrorAction SilentlyContinue) {
			chmod +x $dest
		}
	}
	Write-Success "git hooks installed"
}

<#
.SYNOPSIS
Format code

.DESCRIPTION
Format all Go code in this project

.EXAMPLE
Format-Project
#>
Function Format-Project {
	go fmt "./..."
	Write-Success "go style guide applied"
	go mod tidy
	Write-Success "dependencies tidied up"
}

<#
.SYNOPSIS
Run unit tests

.DESCRIPTION
Run unit tests for this project and all its packages

.EXAMPLE
Invoke-Tests
#>
Function Invoke-Tests {
	$module = (Get-GoModule)
	Write-Info "running tests"
	$output = (go test "./..." --cover)
	$failed = 0
	$total = 0
	ForEach ($line In ($output | Select-String -AllMatches -Pattern "\w\s+$module")) {
		$status, $module, $coverage = Get-TestDetails($line)
		$total++
		If ($status -Like "ok*") {
			Write-Pass "$module , $coverage" 	
		} Else {
			$failed++
			Write-Failure "$module , $coverage"
		}
	}
	Write-Output " ----".PadLeft(5)
	If ((Assert-ExitCode 0) -and ($failed -eq 0)) {
		If ($total -gt 0) {
			Write-Success "all tests passing"
		} Else {
			Write-Warning "no unit tests"
		}
	} Else {
		Write-Failure "$failed of $total packages failing"
		Write-Output ""
		Write-Output $output
	}
}

Function Get-TestDetails($testOutput) {
	$parts = ($line -Split "\t")
	Return $parts[0].ToUpper(), $parts[1], $parts[-1]
}

<#
.SYNOPSIS
Examine code for common flaws

.DESCRIPTION
Examine Go source code and report suspicious constructs

.EXAMPLE
Invoke-Checks
#>

Function Invoke-Checks {
	Write-Info "examining packages"
	$lint = "golangci-lint run"
	if (-Not (Get-Command -Name "golangci-lint" -ErrorAction SilentlyContinue)) {
		Write-Warning "golangci-lint is not installed, using `go vet` "
		$lint = "go vet ./..."
	}
	Invoke-Expression $lint
	If (Assert-ExitCode 0) {
		Write-Success "no problems detected"
	} Else {
		Write-Failure "detected a few problems"
	}
}

<#
.SYNOPSIS
Run gitfloss commands

.DESCRIPTION
Run this project in the current terminal

.EXAMPLE
Invoke-Run --help
#>
Function Invoke-Run {
	go run . @args
}

<#
.SYNOPSIS
Build this project

.DESCRIPTION
Create an executable from this project

.EXAMPLE
Build-Project
#>

Function Build-Project {
	$binary = (Get-ProjectName)
	if ($IsWindows) {
		$binary += ".exe"
	}
	Write-Info "building $binary"
	go build -o $binary .
	Write-Success "built executable '$binary'"
}

<#
.SYNOPSIS
Publish a version to pkg.go.dev

.DESCRIPTION
Add the specified version to pkg.go.dev
Expects the version tag to exist on the repository

.EXAMPLE
Publish-Version v2.0.0
#>
Function Publish-Version($version) {
	$module=(Get-GoModule)
	Write-Info "publishing $version of $module to pkg.go.dev"
	If (Invoke-WebRequest -Uri "http://proxy.golang.org/${module}/@v/${version}.zip") {
		Write-Success "published to https://pkg.go.dev/mod/${module}@${version}"
	}
}

##########################################################################################

Export-ModuleMember -Function Install-Project
Export-ModuleMember -Function Format-Project
Export-ModuleMember -Function Invoke-Tests
Export-ModuleMember -Function Invoke-Checks
Export-ModuleMember -Function Invoke-Run
Export-ModuleMember -Function Build-Project
Export-ModuleMember -Function Publish-Version

##########################################################################################
#                                 Utility Functions                                      #
##########################################################################################

$LEFT_PAD = 5

function Assert-ExitCode($expectedExitCode)
{
	return ($LASTEXITCODE -eq $expectedExitCode)
}

Function Write-Success($message) {
	Write-Host -NoNewline -ForegroundColor Green "ok".PadLeft($LEFT_PAD)
	Write-Host " : $message"
}

Function Write-Pass($message) {
	Write-Host -NoNewline -ForegroundColor Green "pass".PadLeft($LEFT_PAD)
	Write-Host " : $message"
}
Function Write-Failure($message) {
	Write-Host -NoNewline -ForegroundColor Red "fail".PadLeft($LEFT_PAD)
	Write-Host " : $message"
}

Function Write-Warning($message) {
	Write-Host -NoNewline -ForegroundColor Yellow "warn".PadLeft($LEFT_PAD)
	Write-Host " : $message"
}

Function Write-Error($message) {
	Write-Host -NoNewline -ForegroundColor Red "error".PadLeft($LEFT_PAD)
	Write-Host " : $message"
	Throw $message
}

Function Write-Info($message) {
	Write-Host -NoNewline -ForegroundColor CYAN "info".PadLeft($LEFT_PAD)
	Write-Host " : $message"
}

<#
.SYNOPSIS
Get the Go module path

.DESCRIPTION
Get the Go module path based on the local `go.mod` file
#>
Function Get-GoModule {
	Return ((Get-Content go.mod)[0] -Split " ")[-1]
}

<#
.SYNOPSIS
Get the project name
#>
Function Get-ProjectName {
	$module = (Get-GoModule)
	return ($module -Split '/')[-1]
}