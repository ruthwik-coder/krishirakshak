$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
}

Write-Host "=== Checking Alerts Table ==="
try {
    $alerts = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/rest/v1/alerts?limit=5&order=created_at.desc" -Headers $headers
    if ($alerts.Count -eq 0) {
        Write-Host "No alerts in database yet"
    } else {
        Write-Host "Alerts found: $($alerts.Count)"
        $alerts | ConvertTo-Json -Depth 3
    }
} catch {
    Write-Host "Error fetching alerts: $($_.Exception.Message)"
}

Write-Host "`n=== Checking Storage Buckets ==="
try {
    $buckets = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/storage/v1/bucket" -Headers $headers
    Write-Host "Buckets:"
    $buckets | ConvertTo-Json -Depth 3
} catch {
    Write-Host "Error fetching buckets: $($_.Exception.Message)"
}

Write-Host "`n=== Testing Insert Alert ==="
$body = @{
    "device_code" = "LAPTOP001"
    "intruder_type" = "person"
    "confidence" = 0.95
    "image_url" = "https://example.com/test.jpg"
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/rest/v1/alerts" -Headers $headers -Method Post -Body $body -ContentType "application/json"
    Write-Host "Alert inserted successfully!"
    $result | ConvertTo-Json -Depth 3
} catch {
    Write-Host "Error inserting alert: $($_.Exception.Message)"
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $responseBody = $reader.ReadToEnd()
    Write-Host "Response: $responseBody"
}