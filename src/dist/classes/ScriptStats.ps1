class ScriptStats {
    [System.Collections.ArrayList] $actionsRun
    [System.Collections.ArrayList] $workItemsRun

    ScriptStats () {
        $this.actionsRun = [System.Collections.ArrayList] @()
        $this.workItemsRun = [System.Collections.ArrayList] @()
    }

    hidden [string] FormatAction ([string] $account, [string] $action) {
        return "${account}:$action"
    }

    hidden [string] FormatWorkItem ([string] $workItem) {
        return $workItem
    }

    [void] AddAction ([string] $account, [string] $action) {
        [void] $this.actionsRun.Add($this.FormatAction($account, $action))
    }

    [System.Boolean] HasAction([string] $account, [string] $action) {
        return $this.actionsRun.Contains($this.FormatAction($account, $action))
    }

    [void] RemoveAction([string] $account, [string] $action) {
        [void] $this.actionsRun.Remove($this.FormatAction($account, $action))
    }

    [void] AddWorkItem ([string] $workItem) {
        [void] $this.workItemsRun.Add($this.FormatWorkItem($workItem))
    }

    [void] Print () {
        Write-Log "Finished processing $($this.workItemsRun.Count) work items with $($this.actionsRun.Count) actions"
        if ($this.workItemsRun.Count -gt 0) { Write-Log "Work Items Processed:`n$($this.workItemsRun -join ",")" 3 }
        if ($this.actionsRun.Count -gt 0) { Write-Log "Actions Processed:`n$($this.actionsRun -join ",")" 3 }
    }
}