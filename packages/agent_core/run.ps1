# 编译一次后直接运行，避免每次启动显示构建日志和 Windows 批处理的退出提示。
$ErrorActionPreference = 'Stop'
$agentArguments = $args
$agentRoot = $PSScriptRoot
$agentOutput = Join-Path $agentRoot '.dart_tool/agent-cli'
$agentExecutable = Join-Path $agentOutput 'bundle/bin/agent.exe'
$agentInputs = Get-ChildItem -LiteralPath (Join-Path $agentRoot 'lib'), (Join-Path $agentRoot 'bin') -Recurse -File
$agentInputs += Get-Item -LiteralPath (Join-Path $agentRoot 'pubspec.lock')
$agentNeedsBuild = -not (Test-Path -LiteralPath $agentExecutable)
if (-not $agentNeedsBuild) {
    $agentBuildTime = (Get-Item -LiteralPath $agentExecutable).LastWriteTimeUtc
    $agentNeedsBuild = @($agentInputs | Where-Object { $_.LastWriteTimeUtc -gt $agentBuildTime }).Count -gt 0
}
Push-Location -LiteralPath $agentRoot
try {
    if ($agentNeedsBuild) {
        Write-Host '正在准备 MissionBook Agent，首次启动需要稍等片刻。'
        New-Item -ItemType Directory -Path $agentOutput -Force | Out-Null
        $agentBuildLog = Join-Path $agentRoot '.dart_tool/agent-cli-build.log'
        & dart build cli --target=bin/agent.dart "--output=$agentOutput" *> $agentBuildLog
        if ($LASTEXITCODE -ne 0) {
            Get-Content -LiteralPath $agentBuildLog -Tail 20
            throw 'Agent 构建失败，请查看上面的错误。'
        }
    }
    & $agentExecutable @agentArguments
    exit $LASTEXITCODE
}
finally { Pop-Location }
