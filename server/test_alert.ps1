$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
}

$userId = "1394378f-581f-4a69-9367-7d46b72649c3"

# Insert with owner_id
$body = @{
    "device_code" = "LAPTOP001"
    "intruder_type" = "person"
    "image_url" = "https://example.com/test.jpg"
    "owner_id" = $userId
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/rest/v1/alerts" -Headers $headers -Method Post -Body $body -ContentType "application/json"
    Write-Host "Alert inserted successfully!"
    $result | ConvertTo-Json -Depth 3
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $responseBody = $reader.ReadToEnd()
    Write-Host "Response: $responseBody"
}