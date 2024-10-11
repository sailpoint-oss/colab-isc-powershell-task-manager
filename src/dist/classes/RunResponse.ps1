class RunResponse {
    [string] $status
    [string] $errorMessage

    RunResponse([string] $status = $null, [string] $errorMessage = $null) {
        if ($null -eq $status) {
            $this.status = "ERROR"
            $this.errorMessage = "Invalid status supplied for the script exit."
            return
        } 

        if ($status -ne "COMPLETED") {
            $this.errorMessage = $errorMessage
        }

        $this.status = $status
    }
}