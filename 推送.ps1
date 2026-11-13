# 一键把本目录推到 GitHub（需在 PowerShell 7 / pwsh 下运行，中文才不会乱码）
# 用法：在本目录执行   pwsh -File .\推送.ps1
# 说明：令牌只存在内存里，推送完立即清空；不写入 .git-credentials，不留在命令历史。

$ErrorActionPreference = 'Stop'

function Say($t){ Write-Host $t -ForegroundColor Cyan }
function Warn($t){ Write-Host $t -ForegroundColor Yellow }

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $here

if(-not (Test-Path (Join-Path $here '.git'))){ Warn "当前目录不是 git 仓库，先回到归档目录执行初始化。"; exit 1 }

Say "== 第 1 步：仓库信息 =="
$user = Read-Host "GitHub 用户名（例如 zhangsan）"
if([string]::IsNullOrWhiteSpace($user)){ Warn "用户名不能为空"; exit 1 }
$defaultRepo = 'link-archive'
$repo = Read-Host "仓库名（直接回车 = $defaultRepo）"
if([string]::IsNullOrWhiteSpace($repo)){ $repo = $defaultRepo }

$url = "https://github.com/$user/$repo.git"
Say "目标仓库：$url"

$existing = (git remote 2>$null)
if($existing -contains 'origin'){ git remote remove origin | Out-Null }
git remote add origin $url

Say "== 第 2 步：粘贴访问令牌 =="
Warn "令牌在 https://github.com/settings/tokens 生成（classic，勾 repo）。输入时不显示。"
$secure = Read-Host "访问令牌" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$pat = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

if([string]::IsNullOrWhiteSpace($pat)){ Warn "令牌为空，已退出"; exit 1 }

Say "== 第 3 步：推送 =="
$env:GH_USER = $user
$env:GH_PAT  = $pat
try{
    git -c 'credential.helper=!f() { echo username=$GH_USER; echo password=$GH_PAT; }; f' push -u origin main
    $pushOk = ($LASTEXITCODE -eq 0)
}finally{
    # 无论成败都清掉内存与子进程环境变量
    $env:GH_PAT = $null
    $env:GH_USER = $null
    $pat = $null
    $secure = $null
    [GC]::Collect()
}

if(-not $pushOk){
    Warn "推送失败。常见原因："
    Write-Host "  · 仓库还没在 GitHub 上创建 → 先去 https://github.com/new 建一个空的 public 仓库"
    Write-Host "  · 令牌权限不足 → classic 令牌要勾 repo"
    Write-Host "  · 令牌过期或复制不全"
    Write-Host "  · 用户名/仓库名写错"
    exit 1
}

Say "== 推送成功 =="
Write-Host ""
Write-Host "下一步：打开 https://github.com/$user/$repo/settings/pages" -ForegroundColor Green
Write-Host "  Source 选 Deploy from a branch → Branch 选 main → 目录选 / (root) → Save"
Write-Host ""
Write-Host "等 1-2 分钟后访问："
Write-Host "  https://$user.github.io/$repo/" -ForegroundColor Green
Write-Host "  https://$user.github.io/$repo/archive.html  （阅读版直达）"
Write-Host "  https://$user.github.io/$repo/archive.pdf   （PDF 直达）"
