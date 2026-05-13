$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
}

# Check LAPTOP001 device
try {
    $response = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/rest/v1/device_registrations?device_code=eq.LAPTOP001" -Headers $headers
    Write-Host "LAPTOP001 device:"
    $response | ConvertTo-Json -Depth 5
    
    # Check owner_id
    if ($response[0].owner_id) {
        Write-Host "`nOwner ID: $($response[0].owner_id)"
    } else {
        Write-Host "`nOwner ID: NOT SET (this is why app doesn't show it)"
    }
    
    Write-Host "`nStream URL: $($response[0].stream_url)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}

# Check if LAPTOP001 exists at all
Write-Host "`n`nAll devices in DB:"
$all = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/rest/v1/device_registrations?select=device_code,owner_id,stream_url" -Headers $headers
$all | ConvertTo-Json -Depth 3