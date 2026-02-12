Write-Host "Building Flutter web..."
flutter build web --base-href /Food-Truck-Inventory/

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed. Stopping."
    exit
}

Write-Host "Resetting docs folder..."
Remove-Item -Recurse -Force docs -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path docs | Out-Null

Write-Host "Copying build files..."
Copy-Item -Recurse -Force build\web\* docs\

Write-Host "Committing..."
git add .
git commit -m "Deploy update"

Write-Host "Pushing..."
git push origin main

Write-Host "Done."