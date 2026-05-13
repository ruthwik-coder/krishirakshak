$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
}

Write-Host "All devices now:"
$all = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/rest/v1/device_registrations" -Headers $headers
$all | ConvertTo-Json -Depth 4